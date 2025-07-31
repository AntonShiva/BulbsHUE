//
//  HueBridgeDiscovery.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 31.07.2025.
//

import Foundation
import Network
import Combine

/// Протокол для discovery методов
protocol BridgeDiscoveryMethod {
    func discoverBridges(completion: @escaping ([Bridge]) -> Void)
}

/// Главный класс для обнаружения Hue Bridge
/// Использует рекомендованный Philips метод через mDNS
class HueBridgeDiscovery {
    
    // MARK: - Properties
    
    private var mdnsDiscovery: MDNSBridgeDiscovery
    private var cloudDiscovery: CloudBridgeDiscovery
    
    // MARK: - Initialization
    
    init() {
        self.mdnsDiscovery = MDNSBridgeDiscovery()
        self.cloudDiscovery = CloudBridgeDiscovery()
    }
    
    // MARK: - Public Methods
    
    /// Запускает комплексный поиск мостов (mDNS + Cloud параллельно)
    func discoverBridges(completion: @escaping ([Bridge]) -> Void) {
        print("🔍 Запускаем комплексный поиск Hue Bridge...")
        
        var allBridges: [Bridge] = []
        let group = DispatchGroup()
        
        // mDNS поиск (рекомендованный метод)
        group.enter()
        mdnsDiscovery.discoverBridges { bridges in
            print("📡 mDNS нашел \(bridges.count) мостов")
            allBridges.append(contentsOf: bridges)
            group.leave()
        }
        
        // Cloud поиск (fallback)
        group.enter()
        cloudDiscovery.discoverBridges { bridges in
            print("☁️ Cloud нашел \(bridges.count) мостов")
            allBridges.append(contentsOf: bridges)
            group.leave()
        }
        
        // Возвращаем уникальные мосты
        group.notify(queue: .main) {
            let uniqueBridges = Array(Set(allBridges))
            print("✅ Всего найдено уникальных мостов: \(uniqueBridges.count)")
            completion(uniqueBridges)
        }
    }
}

/// mDNS Discovery через NetServiceBrowser (рекомендованный метод)
class MDNSBridgeDiscovery: NSObject, BridgeDiscoveryMethod {
    
    // MARK: - Properties
    
    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private var completion: (([Bridge]) -> Void)?
    private var discoveredBridges: [Bridge] = []
    private let discoveryTimeout: TimeInterval = 5.0
    
    // MARK: - Public Methods
    
    func discoverBridges(completion: @escaping ([Bridge]) -> Void) {
        print("🔍 Запускаем mDNS поиск _hue._tcp.local...")
        
        self.completion = completion
        self.discoveredBridges = []
        self.services = []
        
        // Создаем browser для поиска _hue._tcp сервисов
        browser = NetServiceBrowser()
        browser?.delegate = self
        
        // Запускаем поиск
        browser?.searchForServices(ofType: "_hue._tcp.", inDomain: "local.")
        
        // Таймаут через 5 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + discoveryTimeout) { [weak self] in
            self?.finishDiscovery()
        }
    }
    
    // MARK: - Private Methods
    
    private func finishDiscovery() {
        browser?.stop()
        browser = nil
        
        print("⏱️ mDNS поиск завершен, найдено мостов: \(discoveredBridges.count)")
        completion?(discoveredBridges)
        completion = nil
    }
    
    private func resolveService(_ service: NetService) {
        print("🔄 Резолвим сервис: \(service.name)")
        service.delegate = self
        service.resolve(withTimeout: 3.0)
        services.append(service)
    }
    
    private func extractBridgeInfo(from service: NetService) {
        guard let addresses = service.addresses, !addresses.isEmpty else {
            print("❌ Нет адресов у сервиса \(service.name)")
            return
        }
        
        // Извлекаем IP адрес
        var ipAddress: String?
        for addressData in addresses {
            let address = addressData.withUnsafeBytes { bytes in
                bytes.bindMemory(to: sockaddr.self).baseAddress!
            }
            
            if address.pointee.sa_family == AF_INET {
                // IPv4
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(address, socklen_t(addressData.count),
                              &hostname, socklen_t(hostname.count),
                              nil, 0, NI_NUMERICHOST) == 0 {
                    ipAddress = String(cString: hostname)
                    break
                }
            }
        }
        
        guard let ip = ipAddress else {
            print("❌ Не удалось извлечь IP адрес")
            return
        }
        
        print("✅ Найден IP: \(ip), порт: \(service.port)")
        
        // Извлекаем Bridge ID из имени сервиса
        // Формат: "Philips Hue - XXXXXX" где XXXXXX - последние 6 цифр Bridge ID
        var bridgeId = service.name
        if service.name.contains(" - ") {
            let components = service.name.components(separatedBy: " - ")
            if components.count > 1 {
                bridgeId = components.last ?? service.name
            }
        }
        
        // Создаем временный Bridge объект
        let tempBridge = Bridge(
            id: bridgeId,
            internalipaddress: ip,
            port: 443, // HTTPS порт по умолчанию
            name: service.name
        )
        
        // Валидируем мост через /description.xml
        validateBridge(tempBridge) { [weak self] validatedBridge in
            if let bridge = validatedBridge {
                DispatchQueue.main.async {
                    self?.discoveredBridges.append(bridge)
                    print("✅ Добавлен валидный мост: \(bridge)")
                }
            }
        }
    }
    
    /// Валидирует мост и получает его реальный ID
    private func validateBridge(_ bridge: Bridge, completion: @escaping (Bridge?) -> Void) {
        // Сначала пробуем /description.xml (работает без авторизации)
        let descriptionURL = URL(string: "http://\(bridge.internalipaddress)/description.xml")!
        
        print("🔍 Валидируем мост через \(descriptionURL)")
        
        var request = URLRequest(url: descriptionURL)
        request.timeoutInterval = 3.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Ошибка при валидации: \(error)")
                // Пробуем альтернативный метод
                self.validateBridgeViaAPI(bridge, completion: completion)
                return
            }
            
            guard let data = data,
                  let xmlString = String(data: data, encoding: .utf8) else {
                print("❌ Нет данных от моста")
                completion(nil)
                return
            }
            
            // Парсим XML для получения информации о мосте
            if let bridgeInfo = self.parseDescriptionXML(xmlString) {
                var validatedBridge = bridge
                validatedBridge.id = bridgeInfo.serialNumber
                validatedBridge.name = bridgeInfo.friendlyName
                
                print("✅ Мост валидирован через XML: ID=\(validatedBridge.id)")
                completion(validatedBridge)
            } else {
                // Пробуем альтернативный метод
                self.validateBridgeViaAPI(bridge, completion: completion)
            }
        }.resume()
    }
    
    /// Альтернативная валидация через /api/config
    private func validateBridgeViaAPI(_ bridge: Bridge, completion: @escaping (Bridge?) -> Void) {
        let configURL = URL(string: "https://\(bridge.internalipaddress)/api/config")!
        
        print("🔍 Пробуем валидацию через API: \(configURL)")
        
        var request = URLRequest(url: configURL)
        request.timeoutInterval = 3.0
        
        // Создаем session с игнорированием сертификата для локальных IP
        let session = URLSession(configuration: .default, delegate: TrustAllCertsDelegate(), delegateQueue: nil)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Ошибка API: \(error)")
                // Все равно добавляем мост, так как он отвечает
                completion(bridge)
                return
            }
            
            guard let data = data else {
                print("❌ Нет данных от API")
                completion(bridge)
                return
            }
            
            // Пробуем декодировать JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let bridgeId = json["bridgeid"] as? String {
                    var validatedBridge = bridge
                    validatedBridge.id = bridgeId
                    validatedBridge.name = json["name"] as? String ?? "Philips Hue Bridge"
                    
                    print("✅ Мост валидирован через API: ID=\(validatedBridge.id)")
                    completion(validatedBridge)
                } else {
                    print("⚠️ Неожиданный формат ответа API")
                    completion(bridge)
                }
            } catch {
                print("❌ Ошибка парсинга JSON: \(error)")
                // Логируем что получили
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Ответ: \(responseString)")
                }
                completion(bridge)
            }
        }.resume()
    }
    
    /// Парсит description.xml для получения информации о мосте
    private func parseDescriptionXML(_ xml: String) -> (serialNumber: String, friendlyName: String)? {
        // Простой парсинг XML без использования XMLParser
        var serialNumber: String?
        var friendlyName: String?
        
        // Извлекаем serialNumber
        if let serialRange = xml.range(of: "<serialNumber>"),
           let serialEndRange = xml.range(of: "</serialNumber>") {
            let startIndex = serialRange.upperBound
            let endIndex = serialEndRange.lowerBound
            serialNumber = String(xml[startIndex..<endIndex])
        }
        
        // Извлекаем friendlyName
        if let nameRange = xml.range(of: "<friendlyName>"),
           let nameEndRange = xml.range(of: "</friendlyName>") {
            let startIndex = nameRange.upperBound
            let endIndex = nameEndRange.lowerBound
            friendlyName = String(xml[startIndex..<endIndex])
        }
        
        // Проверяем что это действительно Hue Bridge
        let isHueBridge = xml.contains("Philips hue") ||
                         xml.contains("Royal Philips") ||
                         xml.contains("modelName>Philips hue bridge")
        
        if isHueBridge, let serial = serialNumber {
            return (serial, friendlyName ?? "Philips Hue Bridge")
        }
        
        return nil
    }
}

// MARK: - NetServiceBrowserDelegate

extension MDNSBridgeDiscovery: NetServiceBrowserDelegate {
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("📡 Найден mDNS сервис: \(service.name) типа \(service.type)")
        resolveService(service)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("📡 Удален mDNS сервис: \(service.name)")
        services.removeAll { $0 == service }
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("🛑 mDNS поиск остановлен")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("❌ Ошибка mDNS поиска: \(errorDict)")
        
        // Проверяем код ошибки
        if let errorCode = errorDict[NetService.errorCode] as? Int {
            switch errorCode {
            case -72008:
                print("🚫 Ошибка -72008: Разрешение на локальную сеть отклонено")
                // Можно добавить обработку этой ошибки
            default:
                print("❌ Код ошибки: \(errorCode)")
            }
        }
        
        finishDiscovery()
    }
}

// MARK: - NetServiceDelegate

extension MDNSBridgeDiscovery: NetServiceDelegate {
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        print("✅ Адрес резолвлен для: \(sender.name)")
        extractBridgeInfo(from: sender)
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("❌ Не удалось резолвить: \(sender.name), ошибка: \(errorDict)")
    }
}

/// Cloud Discovery через N-UPnP (fallback метод)
class CloudBridgeDiscovery: BridgeDiscoveryMethod {
    
    func discoverBridges(completion: @escaping ([Bridge]) -> Void) {
        print("☁️ Запускаем поиск через Philips Cloud (N-UPnP)...")
        
        guard let url = URL(string: "https://discovery.meethue.com") else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Ошибка Cloud поиска: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("❌ Нет данных от Cloud")
                completion([])
                return
            }
            
            do {
                let bridges = try JSONDecoder().decode([Bridge].self, from: data)
                print("✅ Cloud нашел мостов: \(bridges.count)")
                completion(bridges)
            } catch {
                print("❌ Ошибка декодирования Cloud ответа: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Ответ Cloud: \(responseString)")
                }
                completion([])
            }
        }.resume()
    }
}

/// Делегат для игнорирования самоподписанных сертификатов (только для локальных IP)
class TrustAllCertsDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
