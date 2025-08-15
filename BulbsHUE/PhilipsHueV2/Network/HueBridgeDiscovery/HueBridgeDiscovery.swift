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

        func finishEarly(with bridges: [Bridge]) {
            self.isDiscovering = false
            let normalized = bridges.map { b -> Bridge in
                var nb = b; nb.id = b.normalizedId; return nb
            }
            DispatchQueue.main.async {
                print("🎯 mDNS нашёл мост(ы): \(normalized.count). Раннее завершение поиска")
                for bridge in normalized {
                    print("   - \(bridge.name ?? "Unknown") (\(bridge.id)) at \(bridge.internalipaddress)")
                }
                print("📋 Discovery завершен с результатом: \(normalized.count) мостов")
                completion(normalized)
            }
        }

        if #available(iOS 14.0, *) {
            attemptMDNSDiscovery { bridges in
                if !bridges.isEmpty {
                    finishEarly(with: bridges)
                    return
                }

                var allFoundBridges: [Bridge] = []
                let lock = NSLock()
                var completedTasks = 0
                let totalTasks = 3

                func safeTaskCompletion(bridges: [Bridge], taskName: String) {
                    lock.lock()
                    defer { lock.unlock() }

                    print("✅ \(taskName) завершен, найдено: \(bridges.count) мостов")

                    if taskName == "Cloud Discovery", !bridges.isEmpty {
                        finishEarly(with: bridges)
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

                    completedTasks += 1

                    if completedTasks >= totalTasks {
                        self.isDiscovering = false
                        DispatchQueue.main.async {
                            print("🎯 Найдено всего уникальных мостов: \(allFoundBridges.count)")
                            for bridge in allFoundBridges {
                                print("   - \(bridge.name ?? "Unknown") (\(bridge.id)) at \(bridge.internalipaddress)")
                            }
                            print("📋 Discovery завершен с результатом: \(allFoundBridges.count) мостов")
                            completion(allFoundBridges)
                        }
                    }
                }

                self.cloudDiscovery { bridges in
                    if !bridges.isEmpty {
                        finishEarly(with: bridges)
                        return
                    }

                    SmartBridgeDiscovery.discoverBridgeIntelligently { bridges in
                        safeTaskCompletion(bridges: bridges, taskName: "Smart Discovery")
                    }

                    self.ipScanDiscovery { bridges in
                        safeTaskCompletion(bridges: bridges, taskName: "Legacy IP Scan")
                    }

                    DispatchQueue.global().asyncAfter(deadline: .now() + self.discoveryTimeout) { [weak self] in
                        guard let self = self, self.isDiscovering else { return }
                        self.isDiscovering = false
                        DispatchQueue.main.async {
                            print("⏰ Таймаут поиска, найдено мостов: \(allFoundBridges.count)")
                            if allFoundBridges.isEmpty {
                                print("❌ Мосты не найдены")
                                NetworkDiagnostics.generateDiagnosticReport { report in
                                    print("🔍 ДИАГНОСТИЧЕСКИЙ ОТЧЕТ:")
                                    print(report)
                                }
                            }
                            completion(allFoundBridges)
                        }
                    }
                }
            }
        } else {
            var allFoundBridges: [Bridge] = []
            let lock = NSLock()
            var completedTasks = 0
            let totalTasks = 3

            func safeTaskCompletion(bridges: [Bridge], taskName: String) {
                lock.lock(); defer { lock.unlock() }
                print("✅ \(taskName) завершен, найдено: \(bridges.count) мостов")
                let uniqueBridges = bridges.filter { newBridge in
                    !allFoundBridges.contains { existing in
                        existing.normalizedId == newBridge.normalizedId ||
                        existing.internalipaddress == newBridge.internalipaddress
                    }
                }
                allFoundBridges.append(contentsOf: uniqueBridges)
                completedTasks += 1
                if completedTasks >= totalTasks {
                    isDiscovering = false
                    DispatchQueue.main.async { completion(allFoundBridges) }
                }
            }

            cloudDiscovery { bridges in safeTaskCompletion(bridges: bridges, taskName: "Cloud Discovery") }
            SmartBridgeDiscovery.discoverBridgeIntelligently { bridges in safeTaskCompletion(bridges: bridges, taskName: "Smart Discovery") }
            ipScanDiscovery { bridges in safeTaskCompletion(bridges: bridges, taskName: "Legacy IP Scan") }
        }
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
