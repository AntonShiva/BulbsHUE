//
//  HueBridgeDiscovery+IPScan.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/15/25.
//

import Foundation

@available(iOS 12.0, *)
extension HueBridgeDiscovery {
    
    // MARK: - IP Scan Discovery
    
    internal func ipScanDiscovery(shouldStop: @escaping () -> Bool = { false }, completion: @escaping ([Bridge]) -> Void) {
        print("🔍 Сканируем популярные IP адреса...")
        
        var hasCompleted = false
        let ipScanLock = NSLock()
        
        func safeCompletion(_ bridges: [Bridge]) {
            ipScanLock.lock()
            defer { ipScanLock.unlock() }
            
            guard !hasCompleted && !shouldStop() else { 
                if shouldStop() {
                    print("🛑 IP Scan: остановлен внешним shouldStop")
                }
                return 
            }
            hasCompleted = true
            completion(bridges)
        }
        
        var commonIPs = [
            "192.168.1.2", "192.168.1.3", "192.168.1.4", "192.168.1.5", "192.168.1.6", "192.168.1.7", "192.168.1.8", "192.168.1.10",
            "192.168.0.2", "192.168.0.3", "192.168.0.4", "192.168.0.5", "192.168.0.6", "192.168.0.7", "192.168.0.8", "192.168.0.10",
            "192.168.100.2", "192.168.100.3", "192.168.100.4", "192.168.100.5",
            "192.168.86.2", "192.168.86.3", "192.168.86.4", "192.168.86.5",
            "10.0.0.2", "10.0.0.3", "10.0.0.4", "10.0.0.5", "10.0.1.2", "10.0.1.3",
            "172.16.0.2", "172.16.0.3", "172.16.1.2", "172.16.1.3"
        ]
        
        if let deviceIP = SmartBridgeDiscovery.getCurrentDeviceIP() {
            let additionalIPs = generateSubnetIPs(from: deviceIP)
            commonIPs.append(contentsOf: additionalIPs)
            print("🌐 Автоопределена подсеть: добавлено \(additionalIPs.count) IP адресов")
        }
        
        var foundBridges: [Bridge] = []
        var completedIPs = 0
        let totalIPs = commonIPs.count
        
        for ip in commonIPs {
            if !isDiscovering || shouldStop() {
                print("🛑 Останов IP-сканирования (раннее завершение или shouldStop)")
                safeCompletion(foundBridges)
                break
            }
            checkIPWithRetry(ip, maxAttempts: 2, shouldStop: shouldStop) { bridge in
                ipScanLock.lock()
                if let bridge = bridge {
                    let isUnique = !foundBridges.contains { $0.id == bridge.id }
                    if isUnique {
                        foundBridges.append(bridge)
                        print("✅ Найден уникальный мост на \(ip): \(bridge.id)")
                    } else {
                        print("🔄 Мост на \(ip) уже найден: \(bridge.id)")
                    }
                } else {
                    print("❌ Мост не найден на \(ip)")
                }
                
                completedIPs += 1
                
                if completedIPs >= totalIPs {
                    print("🏁 IP сканирование завершено. Найдено уникальных мостов: \(foundBridges.count)")
                    ipScanLock.unlock()
                    safeCompletion(foundBridges)
                    return
                }
                ipScanLock.unlock()
            }
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 15.0) {
            safeCompletion(foundBridges)
        }
    }
    
    private func generateSubnetIPs(from deviceIP: String) -> [String] {
        let components = deviceIP.components(separatedBy: ".")
        guard components.count == 4,
              let subnet = Int(components[2]) else {
            return []
        }
        
        let baseIP = "\(components[0]).\(components[1]).\(subnet)"
        var ips: [String] = []
        
        for i in 2...20 {
            let ip = "\(baseIP).\(i)"
            if ip != deviceIP {
                ips.append(ip)
            }
        }
        
        return ips
    }
    
    private func checkIPWithRetry(_ ip: String, maxAttempts: Int = 2, shouldStop: @escaping () -> Bool = { false }, completion: @escaping (Bridge?) -> Void) {
        func attemptCheck(attempt: Int) {
            if !isDiscovering || shouldStop() {
                completion(nil)
                return
            }
            checkIP(ip, shouldStop: shouldStop) { bridge in
                if bridge != nil || attempt >= maxAttempts || shouldStop() {
                    completion(bridge)
                } else {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        attemptCheck(attempt: attempt + 1)
                    }
                }
            }
        }
        
        attemptCheck(attempt: 1)
    }
    
    internal func checkIP(_ ip: String, shouldStop: @escaping () -> Bool = { false }, completion: @escaping (Bridge?) -> Void) {
        guard !shouldStop() else {
            completion(nil)
            return
        }
        
        checkIPViaConfig(ip, shouldStop: shouldStop) { bridge in
            guard !shouldStop() else {
                completion(nil)
                return
            }
            
            if bridge != nil {
                completion(bridge)
            } else {
                self.checkIPViaXML(ip, shouldStop: shouldStop, completion: completion)
            }
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueBridgeDiscovery+IPScan.swift
 
 Описание:
 Расширение для поиска Hue Bridge путем сканирования популярных IP адресов.
 Используется как резервный метод когда другие способы не работают.
 
 Основные компоненты:
 - ipScanDiscovery - главный метод IP сканирования
 - generateSubnetIPs - генерация IP адресов текущей подсети
 - checkIPWithRetry - проверка IP с повторными попытками
 - checkIP - проверка конкретного IP адреса
 
 Стратегия:
 - Сканирует популярные диапазоны IP (192.168.x.x, 10.0.x.x, 172.16.x.x)
 - Автоматически определяет и сканирует текущую подсеть устройства
 - Параллельная проверка множества IP адресов
 - Retry механизм для нестабильных соединений
 
 Зависимости:
 - SmartBridgeDiscovery для получения IP устройства
 - HueBridgeDiscovery+Validation для методов checkIPViaConfig и checkIPViaXML
 
 Связанные файлы:
 - HueBridgeDiscovery.swift - основной класс
 - HueBridgeDiscovery+Validation.swift - методы проверки IP
 */
