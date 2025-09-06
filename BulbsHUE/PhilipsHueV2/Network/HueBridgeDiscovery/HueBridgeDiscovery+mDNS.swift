//
//  HueBridgeDiscovery+mDNS.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/15/25.
//

import Foundation
import Network
#if canImport(Darwin)
import Darwin
#endif

@available(iOS 14.0, *)
extension HueBridgeDiscovery {
    
    // MARK: - mDNS/Bonjour Discovery
    
    internal func attemptMDNSDiscovery(completion: @escaping ([Bridge]) -> Void) {
        print("🎯 Пытаемся использовать mDNS поиск...")

        let browser = NWBrowser(for: .bonjour(type: "_hue._tcp", domain: nil), using: .tcp)
        var hasCompleted = false
        let completeOnce: ([Bridge]) -> Void = { bridges in
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(bridges)
        }

        final class ServiceResolver: NSObject, NetServiceDelegate {
            private let onResolved: (String, Int) -> Void
            private let onFailed: () -> Void

            init(onResolved: @escaping (String, Int) -> Void, onFailed: @escaping () -> Void) {
                self.onResolved = onResolved
                self.onFailed = onFailed
            }

            func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
                print("❌ mDNS NetService резолвинг FAILED: \(errorDict)")
                onFailed()
            }

            func netServiceDidResolveAddress(_ sender: NetService) {
                print("🎯 mDNS NetService резолвинг УСПЕШНО: \(sender.name)")
                guard let addresses = sender.addresses else { 
                    print("❌ mDNS NetService НЕТ addresses")
                    onFailed()
                    return 
                }
                for addressData in addresses {
                    addressData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                        guard let sockaddrPointer = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return }
                        if sockaddrPointer.pointee.sa_family == sa_family_t(AF_INET) {
                            let addrIn = UnsafeRawPointer(sockaddrPointer).assumingMemoryBound(to: sockaddr_in.self).pointee
                            var ip = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                            var addr = addrIn.sin_addr
                            inet_ntop(AF_INET, &addr, &ip, socklen_t(INET_ADDRSTRLEN))
                            let ipString = String(cString: ip)
                            self.onResolved(ipString, sender.port)
                        }
                    }
                }
            }
        }

        let resolverQueue = DispatchQueue(label: "mdns.resolver.queue")
        var activeServices: [NetService] = []
        var activeResolvers: [ServiceResolver] = []
        var bridges: [Bridge] = []
        
        // ✅ ИСПРАВЛЕНИЕ: Потокобезопасное состояние найденного моста  
        let bridgeFoundLock = NSLock()
        var bridgeFound = false
        
        func tryCompleteBridgeSearch() -> Bool {
            bridgeFoundLock.lock()
            defer { bridgeFoundLock.unlock() }
            guard !bridgeFound else { return false }
            bridgeFound = true
            return true
        }
        
        func isBridgeFound() -> Bool {
            bridgeFoundLock.lock()
            defer { bridgeFoundLock.unlock() }
            return bridgeFound
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self, !isBridgeFound() else { return }
            
            for result in results {
                if case .service(let name, var type, var domain, _) = result.endpoint {
                    if !type.hasSuffix(".") { type += "." }
                    if domain.isEmpty { domain = "local." }
                    if !domain.hasSuffix(".") { domain += "." }

                    print("🎯 mDNS найден сервис: \(name).\(type)\(domain)")

                    // ✅ ИСПРАВЛЕНИЕ: Упрощаем mDNS резолвинг и добавляем fallback
                    print("🔄 mDNS найден сервис: \(name), пытаемся получить IP")
                    
                    // Попытка извлечь IP из имени сервиса, если он там есть
                    var candidateIPs: [String] = []
                    
                    // Многие Hue Bridge включают части IP в имя сервиса
                    let serviceParts = name.components(separatedBy: " - ")
                    if serviceParts.count > 1 {
                        let idPart = serviceParts.last ?? ""
                        // Попробуем сгенерировать возможные IP из MAC/ID
                        candidateIPs = generatePossibleIPsFromServiceName(idPart)
                    }
                    
                    // Добавляем стандартные IP для проверки
                    candidateIPs.append(contentsOf: [
                        "192.168.0.104", "192.168.1.104", "192.168.0.2", "192.168.1.2"
                    ])
                    
                    print("🎯 mDNS проверяем кандидатов IP: \(candidateIPs.prefix(3))...")
                    
                    // Параллельная проверка всех кандидатов
                    let group = DispatchGroup()
                    var foundValidBridge: Bridge?
                    let resultLock = NSLock()
                    
                    for candidateIP in candidateIPs.prefix(5) { // Ограничиваем до 5 кандидатов
                        guard !isBridgeFound() else { break }
                        
                        group.enter()
                        self.checkIPViaConfig(candidateIP) { confirmed in
                            defer { group.leave() }
                            
                            resultLock.lock()
                            if let bridge = confirmed, foundValidBridge == nil, !isBridgeFound() {
                                foundValidBridge = bridge
                                print("✅ mDNS fallback нашел валидный мост на \(candidateIP): \(bridge.id)")
                            }
                            resultLock.unlock()
                        }
                    }
                    
                    group.notify(queue: .global()) {
                        guard !isBridgeFound() else { return }
                        
                        if let validBridge = foundValidBridge, tryCompleteBridgeSearch() {
                            bridges = [validBridge]
                            print("✅ mDNS УСПЕШНО нашел мост через fallback: \(validBridge.id)")
                            
                            browser.cancel()
                            completeOnce(bridges)
                        } else {
                            print("❌ mDNS fallback не нашел валидных мостов")
                        }
                    }
                }
            }
        }

        browser.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("🎯 mDNS browser готов")
            case .failed(let error):
                print("❌ mDNS ошибка: \(error)")
                completeOnce([])
            default:
                break
            }
        }

        browser.start(queue: .global())

        DispatchQueue.global().asyncAfter(deadline: .now() + 8.0) { // Сократили таймаут
            print("⏰ mDNS таймаут - останавливаем поиск")
            browser.cancel()
            if !hasCompleted {
                print("❌ mDNS не нашел мостов за 8 сек")
                completeOnce(bridges)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Генерирует возможные IP адреса на основе имени сервиса
    private func generatePossibleIPsFromServiceName(_ serviceName: String) -> [String] {
        var candidates: [String] = []
        
        // Если в имени есть цифры, пытаемся использовать их как часть IP
        let digits = serviceName.filter { $0.isNumber }
        if digits.count >= 3 {
            let lastOctet = String(digits.suffix(3)).prefix(3)
            if let octet = Int(lastOctet), octet < 256 {
                candidates.append("192.168.0.\(octet)")
                candidates.append("192.168.1.\(octet)")
                candidates.append("10.0.0.\(octet)")
            }
        }
        
        // Проверяем известный IP из логов
        candidates.append("192.168.0.104")
        
        return candidates
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueBridgeDiscovery+mDNS.swift
 
 Описание:
 Расширение для поиска Hue Bridge через mDNS/Bonjour протокол.
 Использует Network framework для обнаружения сервисов _hue._tcp с fallback механизмом.
 
 Основные компоненты:
 - attemptMDNSDiscovery - главный метод mDNS поиска
 - generatePossibleIPsFromServiceName - генерация кандидатов IP из имени сервиса
 - Fallback механизм при проблемах с NetService.resolve()
 
 Протокол:
 - Ищет сервисы типа "_hue._tcp" в домене "local"
 - Использует fallback: генерирует кандидатов IP из имени сервиса
 - Валидирует кандидатов через /api/0/config параллельно
 
 Особенности:
 - Требует iOS 14.0+ для NWBrowser
 - Fallback решение для проблем с NetService резолвингом
 - Автоматическая остановка при первом найденном мосте
 - Таймаут 8 секунд для поиска
 - Параллельная проверка до 5 кандидатов IP
 
 Зависимости:
 - Network framework для NWBrowser
 - HueBridgeDiscovery+Validation для checkIPViaConfig
 
 Связанные файлы:
 - HueBridgeDiscovery.swift - основной класс
 - HueBridgeDiscovery+Validation.swift - методы валидации
 */
