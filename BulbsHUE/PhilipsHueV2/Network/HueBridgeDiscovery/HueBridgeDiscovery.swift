import Foundation
import Network

#if canImport(Darwin)
import Darwin
#endif

@available(iOS 12.0, *)
class HueBridgeDiscovery {
    
    // MARK: - Properties
    
    internal var udpConnection: NWConnection?
    internal var isDiscovering = false
    internal let discoveryTimeout: TimeInterval = 40.0
    internal let lock = NSLock()
    
    // MARK: - Public Methods
    
    func discoverBridges(completion: @escaping ([Bridge]) -> Void) {
        print("🔍 Запускаем комплексный поиск Hue Bridge...")
        
        let networkInfo = NetworkDiagnostics.getCurrentNetworkInfo()
        print(networkInfo)
        
        guard !isDiscovering else {
            print("⚠️ Discovery уже выполняется...")
            completion([])
            return
        }
        
        isDiscovering = true
        var hasCompleted = false
        let globalLock = NSLock()
        
        // ✅ ИСПРАВЛЕНИЕ: Единая функция для завершения поиска
        func finishDiscovery(with bridges: [Bridge], reason: String) {
            globalLock.lock()
            defer { globalLock.unlock() }
            
            guard !hasCompleted else { return }
            hasCompleted = true
            self.isDiscovering = false
            
            let normalized = bridges.map { b -> Bridge in
                var nb = b; nb.id = b.normalizedId; return nb
            }
            
            Task { @MainActor in
                print("🎯 \(reason): найдено \(normalized.count) мостов. Завершаем поиск.")
                for bridge in normalized {
                    print("   - \(bridge.name ?? "Unknown") (\(bridge.id)) at \(bridge.internalipaddress)")
                }
                print("📋 Discovery завершен с результатом: \(normalized.count) мостов")
                completion(normalized)
            }
        }

        if #available(iOS 14.0, *) {
            // ✅ ИСПРАВЛЕНИЕ: Последовательный запуск методов
            print("🎯 Шаг 1: Пытаемся использовать mDNS поиск...")
            attemptMDNSDiscovery { bridges in
                if !bridges.isEmpty {
                    print("✅ mDNS успешно нашел мост(ы)!")
                    finishDiscovery(with: bridges, reason: "mDNS Discovery")
                    return
                }
                
                print("🎯 Шаг 2: mDNS не дал результатов, пробуем Cloud Discovery...")
                self.cloudDiscovery { bridges in
                    if !bridges.isEmpty {
                        print("✅ Cloud Discovery успешно нашел мост(ы)!")
                        finishDiscovery(with: bridges, reason: "Cloud Discovery")
                        return
                    }
                    
                    print("🎯 Шаг 3: Cloud не дал результатов, запускаем параллельные методы...")
                    // Только если не нашли через быстрые методы - запускаем медленные
                    var allFoundBridges: [Bridge] = []
                    let slowLock = NSLock()
                    var completedSlowTasks = 0
                    let totalSlowTasks = 2

                    func slowTaskCompletion(bridges: [Bridge], taskName: String) {
                        slowLock.lock()
                        defer { slowLock.unlock() }
                        
                        // Проверяем что поиск еще не завершен
                        globalLock.lock()
                        let stillSearching = !hasCompleted
                        globalLock.unlock()
                        
                        guard stillSearching else { return }

                        print("✅ \(taskName) завершен, найдено: \(bridges.count) мостов")
                        
                        // Если нашли мосты - завершаем немедленно
                        if !bridges.isEmpty {
                            finishDiscovery(with: bridges, reason: taskName)
                            return
                        }

                        let uniqueBridges = bridges.map { b in
                            var normalized = b
                            normalized.id = b.normalizedId
                            return normalized
                        }.filter { newBridge in
                            !allFoundBridges.contains { existing in
                                existing.normalizedId == newBridge.normalizedId ||
                                existing.internalipaddress == newBridge.internalipaddress
                            }
                        }
                        allFoundBridges.append(contentsOf: uniqueBridges)

                        completedSlowTasks += 1

                        if completedSlowTasks >= totalSlowTasks {
                            finishDiscovery(with: allFoundBridges, reason: "Все методы завершены")
                        }
                    }

                    SmartBridgeDiscovery.discoverBridgeIntelligently { bridges in
                        slowTaskCompletion(bridges: bridges, taskName: "Smart Discovery")
                    }

                    self.ipScanDiscovery { bridges in
                        slowTaskCompletion(bridges: bridges, taskName: "Legacy IP Scan")
                    }

                    // Общий таймаут для медленных методов
                    Task { [weak self] in
                        guard let self = self else { return }
                        try await Task.sleep(nanoseconds: UInt64(self.discoveryTimeout * 1_000_000_000))
                        
                        slowLock.lock()
                        let currentBridges = allFoundBridges
                        slowLock.unlock()
                        
                        finishDiscovery(with: currentBridges, reason: "Таймаут поиска")
                    }
                }
            }
        } else {
            // Legacy iOS < 14.0 - последовательный поиск
            print("📱 Используем legacy discovery для iOS < 12.0")
            cloudDiscovery { bridges in
                if !bridges.isEmpty {
                    finishDiscovery(with: bridges, reason: "Cloud Discovery (Legacy)")
                    return
                }
                
                SmartBridgeDiscovery.discoverBridgeIntelligently { bridges in
                    if !bridges.isEmpty {
                        finishDiscovery(with: bridges, reason: "Smart Discovery (Legacy)")
                        return
                    }
                    
                    self.ipScanDiscovery { bridges in
                        finishDiscovery(with: bridges, reason: "IP Scan (Legacy)")
                    }
                }
            }
        }
    }
    
    /// Принудительно останавливает все процессы поиска
    func stopDiscovery() {
        print("🛑 Принудительно останавливаем все процессы поиска...")
        
        lock.lock()
        defer { lock.unlock() }
        
        isDiscovering = false
        udpConnection?.cancel()
        udpConnection = nil
        
        print("✅ Все процессы поиска остановлены")
    }
    
    // MARK: - Cleanup
    
    deinit {
        udpConnection?.cancel()
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueBridgeDiscovery.swift
 
 Описание:
 Основной класс для поиска Philips Hue Bridge в локальной сети.
 Координирует несколько методов поиска для максимальной надежности.
 
 Основные компоненты:
 - Координация различных методов поиска (mDNS, Cloud, IP scan, SSDP)
 - Управление состоянием поиска
 - Агрегация результатов из разных источников
 - Дедупликация найденных мостов
 
 Использование:
 let discovery = HueBridgeDiscovery()
 discovery.discoverBridges { bridges in
     print("Найдено мостов: \(bridges.count)")
 }
 
 Зависимости:
 - Foundation, Network frameworks
 - NetworkDiagnostics для диагностики сети
 - SmartBridgeDiscovery для интеллектуального поиска
 
 Связанные файлы:
 - HueBridgeDiscovery+SSDP.swift - SSDP протокол поиска
 - HueBridgeDiscovery+Cloud.swift - поиск через облако Philips
 - HueBridgeDiscovery+IPScan.swift - сканирование IP адресов
 - HueBridgeDiscovery+mDNS.swift - mDNS/Bonjour поиск
 - HueBridgeDiscovery+Validation.swift - валидация и проверка мостов
 */
