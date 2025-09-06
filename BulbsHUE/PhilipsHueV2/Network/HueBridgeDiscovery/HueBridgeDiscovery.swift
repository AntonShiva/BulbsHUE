import Foundation
import Network

#if canImport(Darwin)
import Darwin
#endif

// ✅ ИСПРАВЛЕНИЕ: Потокобезопасный класс для управления состоянием завершения
private final class CompletionState {
    private let lock = NSLock()
    private var isCompleted = false
    
    func tryComplete() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isCompleted else { return false }
        isCompleted = true
        return true
    }
    
    var completed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCompleted
    }
}

@available(iOS 12.0, *)
class HueBridgeDiscovery {
    
    // MARK: - Properties
    
    internal var udpConnection: NWConnection?
    internal var isDiscovering = false
    internal let discoveryTimeout: TimeInterval = 40.0
    internal let lock = NSLock()
    
    // ✅ ИСПРАВЛЕНИЕ: Добавляем управление Task для proper cancellation
    private var timeoutTask: Task<Void, Never>?
    private var smartDiscoveryTask: Task<Void, Never>?
    private var ipScanTask: Task<Void, Never>?
    
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
        
        // ✅ ИСПРАВЛЕНИЕ: Потокобезопасное состояние завершения
        let completionState = CompletionState()
        
        // ✅ ИСПРАВЛЕНИЕ: Единая функция для завершения поиска с отменой Task
        func finishDiscovery(with bridges: [Bridge], reason: String) {
            guard completionState.tryComplete() else { return }
            
            self.lock.lock()
            self.isDiscovering = false
            self.lock.unlock()
            
            // ✅ ИСПРАВЛЕНИЕ: Отменяем все активные Task'и при завершении
            self.timeoutTask?.cancel()
            self.timeoutTask = nil
            self.smartDiscoveryTask?.cancel()
            self.smartDiscoveryTask = nil
            self.ipScanTask?.cancel()
            self.ipScanTask = nil
            
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
            // ✅ ИСПРАВЛЕНИЕ: СТРОГО последовательное выполнение mDNS → Cloud → Smart/IP
            executeSequentialDiscovery(completionState: completionState, finishDiscovery: finishDiscovery)
        } else {
            // Legacy iOS < 14.0 - последовательный поиск
            print("📱 Используем legacy discovery для iOS < 12.0")
            executeSequentialDiscoveryLegacy(completionState: completionState, finishDiscovery: finishDiscovery)
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
        
        // ✅ ИСПРАВЛЕНИЕ: Отменяем все активные Task'и
        timeoutTask?.cancel()
        timeoutTask = nil
        smartDiscoveryTask?.cancel()
        smartDiscoveryTask = nil
        ipScanTask?.cancel()
        ipScanTask = nil
        
        print("✅ Все процессы поиска остановлены")
    }
    
    // MARK: - Sequential Discovery Implementation
    
    /// СТРОГО последовательное выполнение для iOS 14+ 
    /// Архитектура: mDNS → Cloud → Smart → IP (каждый следующий ТОЛЬКО если предыдущий не нашел)
    @available(iOS 14.0, *)
    private func executeSequentialDiscovery(
        completionState: CompletionState, 
        finishDiscovery: @escaping ([Bridge], String) -> Void
    ) {
        print("🎯 ШАГ 1/4: Запуск mDNS Discovery - ждем полное завершение...")
        
        attemptMDNSDiscovery { [weak self] bridges in
            guard let self = self else { return }
            
            if !bridges.isEmpty {
                print("✅ mDNS УСПЕШНО нашел \(bridges.count) мост(ов) - останавливаем поиск!")
                finishDiscovery(bridges, "mDNS Discovery")
                return
            }
            
            print("❌ mDNS не нашел мостов")
            print("🎯 ШАГ 2/4: Запуск Cloud Discovery - ждем полное завершение...")
            
            self.cloudDiscovery { [weak self] bridges in
                guard let self = self else { return }
                
                if !bridges.isEmpty {
                    print("✅ Cloud Discovery УСПЕШНО нашел \(bridges.count) мост(ов) - останавливаем поиск!")
                    finishDiscovery(bridges, "Cloud Discovery")
                    return
                }
                
                // ✅ ИСПРАВЛЕНИЕ: Агрессивная проверка перед шагом 3
                guard !completionState.completed else {
                    print("🛑 Шаг 3: Discovery уже завершен, пропускаем Smart/IP")
                    return
                }
                
                print("❌ Cloud Discovery не нашел мостов")
                print("🎯 ШАГ 3/4: Запуск Smart Discovery - ждем полное завершение...")
                
                // СТРОГО последовательно: Smart Discovery → IP Scan
                self.executeSequentialSlowDiscovery(completionState: completionState, finishDiscovery: finishDiscovery)
            }
        }
    }
    
    /// Legacy последовательное выполнение для iOS < 14
    private func executeSequentialDiscoveryLegacy(
        completionState: CompletionState,
        finishDiscovery: @escaping ([Bridge], String) -> Void
    ) {
        print("🎯 ШАГ 1/2: Запуск Cloud Discovery (Legacy) - ждем полное завершение...")
        
        cloudDiscovery { [weak self] bridges in
            guard let self = self else { return }
            
            if !bridges.isEmpty {
                print("✅ Cloud Discovery УСПЕШНО нашел \(bridges.count) мост(ов) - останавливаем поиск!")
                finishDiscovery(bridges, "Cloud Discovery (Legacy)")
                return
            }
            
            print("❌ Cloud Discovery не нашел мостов")
            print("🎯 ШАГ 2/2: Запуск Smart Discovery - ждем полное завершение...")
            
            SmartBridgeDiscovery.discoverBridgeIntelligently { [weak self] bridges in
                guard let self = self else { return }
                
                if !bridges.isEmpty {
                    print("✅ Smart Discovery УСПЕШНО нашел \(bridges.count) мост(ов)!")
                    finishDiscovery(bridges, "Smart Discovery (Legacy)")
                    return
                }
                
                print("❌ Smart Discovery не нашел мостов")
                print("🎯 Финальная попытка: IP Scan Discovery...")
                
                self.ipScanDiscovery(shouldStop: { completionState.completed }) { [weak self] bridges in
                    guard let self = self else { return }
                    print("🎯 IP Scan завершен с \(bridges.count) мостами")
                    finishDiscovery(bridges, "IP Scan (Legacy)")
                }
            }
        }
    }
    
    /// Строго последовательное выполнение медленных методов: Smart Discovery → IP Scan
    private func executeSequentialSlowDiscovery(
        completionState: CompletionState,
        finishDiscovery: @escaping ([Bridge], String) -> Void
    ) {
        // Агрессивная проверка перед Smart Discovery
        guard !completionState.completed else {
            print("🛑 executeSequentialSlowDiscovery: Discovery уже завершен")
            return
        }
        
        print("🧠 Запуск Smart Discovery (Шаг 3/4)...")
        
        SmartBridgeDiscovery.discoverBridgeIntelligently(shouldStop: { completionState.completed }) { [weak self] bridges in
            guard let self = self else { return }
            
            // Проверяем завершение после Smart Discovery
            guard !completionState.completed else {
                print("🛑 Smart Discovery: результат отменен - Discovery уже завершен")
                return
            }
            
            if !bridges.isEmpty {
                print("✅ Smart Discovery УСПЕШНО нашел \(bridges.count) мост(ов) - останавливаем поиск!")
                finishDiscovery(bridges, "Smart Discovery")
                return
            }
            
            print("❌ Smart Discovery не нашел мостов")
            
            // Агрессивная проверка перед IP Scan
            guard !completionState.completed else {
                print("🛑 IP Scan: Discovery уже завершен, пропускаем")
                finishDiscovery([], "Smart Discovery завершен без результатов")
                return
            }
            
            print("🎯 ШАГ 4/4: Запуск IP Scan Discovery - последняя попытка...")
            
            self.ipScanDiscovery(shouldStop: { completionState.completed }) { bridges in
                guard !completionState.completed else {
                    print("🛑 IP Scan Discovery: результат отменен - Discovery уже завершен")
                    return
                }
                
                print("🎯 IP Scan Discovery завершен с \(bridges.count) мостами")
                finishDiscovery(bridges, "IP Scan Discovery")
            }
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
 Использует СТРОГО последовательную архитектуру поиска для максимальной эффективности.
 
 АРХИТЕКТУРА ПОИСКА (строго последовательная):
 1. mDNS/Bonjour Discovery (iOS 14+) - быстрый поиск через локальную сеть
 2. Cloud Discovery - поиск через API Philips Hue
 3. Smart Discovery - интеллектуальное сканирование приоритетных IP
 4. IP Scan Discovery - полное сканирование популярных диапазонов IP
 
 ВАЖНО: Каждый следующий метод запускается ТОЛЬКО если предыдущий НЕ нашел мостов.
 При успешном обнаружении на любом этапе - поиск немедленно ОСТАНАВЛИВАЕТСЯ.
 
 Основные компоненты:
 - executeSequentialDiscovery() - главный координатор последовательного поиска
 - executeSequentialSlowDiscovery() - последовательный запуск Smart → IP Discovery
 - CompletionState - потокобезопасное управление состоянием завершения
 - finishDiscovery() - безопасное завершение с отменой всех Task'ов
 
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
 - HueBridgeDiscovery+SSDP.swift - SSDP протокол поиска (не используется в новой архитектуре)
 - HueBridgeDiscovery+Cloud.swift - поиск через облако Philips
 - HueBridgeDiscovery+IPScan.swift - сканирование IP адресов
 - HueBridgeDiscovery+mDNS.swift - mDNS/Bonjour поиск
 - HueBridgeDiscovery+Validation.swift - валидация и проверка мостов
 */
