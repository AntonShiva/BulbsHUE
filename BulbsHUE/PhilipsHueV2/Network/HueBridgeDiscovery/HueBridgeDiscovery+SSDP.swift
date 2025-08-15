//
//  HueBridgeDiscovery+SSDP.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/15/25.
//

import Foundation
import Network

@available(iOS 12.0, *)
extension HueBridgeDiscovery {
    
    // MARK: - SSDP Discovery
    
    internal func ssdpDiscovery(completion: @escaping ([Bridge]) -> Void) {
        print("📡 Запускаем SSDP discovery...")
        
        var foundBridges: [Bridge] = []
        var hasCompleted = false
        let ssdpLock = NSLock()
        
        func safeCompletion(_ bridges: [Bridge]) {
            ssdpLock.lock()
            defer { ssdpLock.unlock() }
            
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(bridges)
        }
        
        let host = NWEndpoint.Host("239.255.255.250")
        let port = NWEndpoint.Port(1900)
        
        let parameters = NWParameters.udp
        
        udpConnection = NWConnection(
            host: host,
            port: port,
            using: parameters
        )
        
        let ssdpRequest = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: urn:schemas-upnp-org:device:basic:1\r
        \r
        
        """.data(using: .utf8)!
        
        udpConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("📡 SSDP соединение готово, отправляем запросы...")
                
                self?.udpConnection?.send(content: ssdpRequest, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ SSDP ошибка отправки основного запроса: \(error)")
                    } else {
                        print("✅ SSDP основной запрос отправлен")
                    }
                })
                
                let rootDeviceRequest = """
                M-SEARCH * HTTP/1.1\r
                HOST: 239.255.255.250:1900\r
                MAN: "ssdp:discover"\r
                MX: 3\r
                ST: upnp:rootdevice\r
                \r
                
                """.data(using: .utf8)!
                
                self?.udpConnection?.send(content: rootDeviceRequest, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ SSDP ошибка отправки rootdevice запроса: \(error)")
                    } else {
                        print("✅ SSDP rootdevice запрос отправлен")
                    }
                })
                
                let hueRequest = """
                M-SEARCH * HTTP/1.1\r
                HOST: 239.255.255.250:1900\r
                MAN: "ssdp:discover"\r
                MX: 3\r
                ST: urn:schemas-upnp-org:device:IpBridge:1\r
                \r
                
                """.data(using: .utf8)!
                
                self?.udpConnection?.send(content: hueRequest, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ SSDP ошибка отправки Hue запроса: \(error)")
                    } else {
                        print("✅ SSDP Hue-специфичный запрос отправлен")
                    }
                })
                
                self?.receiveSSDP { bridges in
                    ssdpLock.lock()
                    foundBridges.append(contentsOf: bridges)
                    ssdpLock.unlock()
                }
                
            case .failed(let error):
                print("❌ SSDP соединение провалилось: \(error)")
                if let nwError = error as? NWError {
                    switch nwError {
                    case .posix(let code):
                        print("🔍 POSIX ошибка: \(code) (\(code.rawValue))")
                    case .dns(let dnsError):
                        print("🔍 DNS ошибка: \(dnsError)")
                    case .tls(let tlsError):
                        print("🔍 TLS ошибка: \(tlsError)")
                    default:
                        print("🔍 Другая ошибка: \(nwError)")
                    }
                }
                safeCompletion([])
                
            case .waiting(let error):
                print("⏳ SSDP ожидание: \(error)")
                
            case .preparing:
                print("🔄 SSDP подготовка соединения...")
                
            case .setup:
                print("⚙️ SSDP настройка соединения...")
                
            case .cancelled:
                print("🚫 SSDP соединение отменено")
                safeCompletion([])
                
            @unknown default:
                print("❓ SSDP неизвестное состояние: \(state)")
                break
            }
        }
        
        udpConnection?.start(queue: .global())
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 6.0) { [weak self] in
            print("📡 SSDP поиск завершен, найдено: \(foundBridges.count) мостов")
            self?.udpConnection?.cancel()
            safeCompletion(foundBridges)
        }
    }
    
    private func receiveSSDP(completion: @escaping ([Bridge]) -> Void) {
        var allBridges: [Bridge] = []
        
        func receiveNext() {
            udpConnection?.receiveMessage { data, context, isComplete, error in
                defer { receiveNext() }
                
                guard let data = data,
                      let response = String(data: data, encoding: .utf8) else {
                    return
                }
                
                if response.contains("IpBridge") || response.contains("hue") {
                    print("🎯 Найден потенциальный Hue Bridge в SSDP ответе")
                    
                    if let locationURL = self.extractLocationURL(from: response) {
                        print("📍 LOCATION URL: \(locationURL)")
                        
                        self.validateHueBridge(locationURL: locationURL) { bridge in
                            if let bridge = bridge {
                                allBridges.append(bridge)
                                print("✅ Подтвержден Hue Bridge: \(bridge.id)")
                            }
                        }
                    }
                }
            }
        }
        
        receiveNext()
    }
    
    internal func extractLocationURL(from response: String) -> String? {
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            if line.lowercased().hasPrefix("location:") {
                return line.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueBridgeDiscovery+SSDP.swift
 
 Описание:
 Расширение для поиска Hue Bridge через SSDP (Simple Service Discovery Protocol).
 Использует UDP multicast для обнаружения UPnP устройств в локальной сети.
 
 Основные компоненты:
 - ssdpDiscovery - главный метод SSDP поиска
 - receiveSSDP - прием и обработка SSDP ответов
 - extractLocationURL - извлечение URL из SSDP ответа
 
 Протокол:
 - Multicast адрес: 239.255.255.250:1900
 - Отправляет M-SEARCH запросы для различных типов устройств
 - Обрабатывает HTTP-подобные ответы с LOCATION заголовком
 
 Зависимости:
 - Network framework для UDP соединений
 - HueBridgeDiscovery+Validation для проверки найденных устройств
 
 Связанные файлы:
 - HueBridgeDiscovery.swift - основной класс
 - HueBridgeDiscovery+Validation.swift - методы валидации
 */
