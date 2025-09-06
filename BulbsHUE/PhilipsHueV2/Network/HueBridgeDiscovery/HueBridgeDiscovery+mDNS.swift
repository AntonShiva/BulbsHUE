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
                onFailed()
            }

            func netServiceDidResolveAddress(_ sender: NetService) {
                guard let addresses = sender.addresses else { onFailed(); return }
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
        var hasFoundBridge = false

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self, !hasFoundBridge else { return }
            
            for result in results {
                if case .service(let name, var type, var domain, _) = result.endpoint {
                    if !type.hasSuffix(".") { type += "." }
                    if domain.isEmpty { domain = "local." }
                    if !domain.hasSuffix(".") { domain += "." }

                    print("🎯 mDNS найден сервис: \(name).\(type)\(domain)")

                    let service = NetService(domain: domain, type: type, name: name)
                    let resolver = ServiceResolver(onResolved: { ip, port in
                        guard !hasFoundBridge else { return }
                        print("🎯 mDNS резолвит IP: \(ip):\(port)")
                        
                        self.checkIPViaConfig(ip) { confirmed in
                            guard !hasFoundBridge else { return }
                            if let bridge = confirmed {
                                hasFoundBridge = true
                                bridges = [bridge]
                                print("✅ mDNS успешно нашел и подтвердил мост: \(bridge.id) на \(ip)")
                                
                                browser.cancel()
                                resolverQueue.async {
                                    activeServices.forEach { $0.stop() }
                                    activeServices.removeAll()
                                    activeResolvers.removeAll()
                                }
                                completeOnce(bridges)
                            }
                        }
                    }, onFailed: {
                        print("❌ mDNS не удалось резолвить сервис: \(name)")
                    })
                    service.delegate = resolver
                    resolverQueue.async {
                        activeServices.append(service)
                        activeResolvers.append(resolver)
                        DispatchQueue.main.async {
                            service.schedule(in: .main, forMode: .common)
                            service.resolve(withTimeout: 5.0) // Увеличен таймаут резолвинга
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

        DispatchQueue.global().asyncAfter(deadline: .now() + 7.0) {
            browser.cancel()
            if !hasCompleted {
                resolverQueue.async { activeServices.forEach { $0.stop() } }
                completeOnce(bridges)
            }
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueBridgeDiscovery+mDNS.swift
 
 Описание:
 Расширение для поиска Hue Bridge через mDNS/Bonjour протокол.
 Использует Network framework для обнаружения сервисов _hue._tcp.
 
 Основные компоненты:
 - attemptMDNSDiscovery - главный метод mDNS поиска
 - ServiceResolver - вспомогательный класс для резолвинга NetService
 - Обработка Bonjour сервисов и извлечение IP адресов
 
 Протокол:
 - Ищет сервисы типа "_hue._tcp" в домене "local"
 - Резолвит найденные сервисы для получения IP адресов
 - Валидирует найденные устройства через /api/0/config
 
 Особенности:
 - Требует iOS 14.0+ для NWBrowser
 - Автоматическая остановка при первом найденном мосте
 - Таймаут 7 секунд для поиска
 
 Зависимости:
 - Network framework для NWBrowser
 - Darwin для работы с sockaddr структурами
 - HueBridgeDiscovery+Validation для checkIPViaConfig
 
 Связанные файлы:
 - HueBridgeDiscovery.swift - основной класс
 - HueBridgeDiscovery+Validation.swift - методы валидации
 */
