//
//  HueBridgeDiscovery.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 31.07.2025.
//

import Foundation
import Network

/// Надежный класс для поиска Philips Hue Bridge через SSDP
/// Работает автономно без зависимости от других приложений
///
/// **РЕШЕНИЕ ПРОБЛЕМЫ:** Этот класс реализует автономный поиск Hue Bridge через SSDP протокол.
/// Больше не требуется запуск стороннего приложения (Hue Essentials) для обнаружения мостов.
///
/// **Как это работает:**
/// 1. SSDP Discovery - отправляет UDP multicast запрос для поиска UPnP устройств
/// 2. Cloud Discovery - проверяет официальный Philips сервис 
/// 3. IP Scan - сканирует популярные IP адреса как запасной вариант
///
/// **Использование:**
/// ```swift
/// let discovery = HueBridgeDiscovery()
/// discovery.discoverBridges { bridges in
///     print("Найдено мостов: \(bridges.count)")
/// }
/// ```
@available(iOS 12.0, *)
class HueBridgeDiscovery {
    
    // MARK: - Properties
    
    private var udpConnection: NWConnection?
    private var isDiscovering = false
    private let discoveryTimeout: TimeInterval = 10.0
    private let lock = NSLock() // Добавляем lock как свойство класса
    
    // MARK: - Public Methods
    
    /// Главный метод поиска - использует SSDP для автономного поиска
    func discoverBridges(completion: @escaping ([Bridge]) -> Void) {
        print("🔍 Запускаем автономный поиск Hue Bridge...")
        
        // Предотвращаем повторные запуски
        guard !isDiscovering else {
            print("⚠️ Discovery уже выполняется...")
            completion([])
            return
        }
        
        isDiscovering = true
        
        var allFoundBridges: [Bridge] = []
        let lock = NSLock()
        var completedTasks = 0
        let totalTasks = 3
        
        // Безопасный wrapper для завершения задач
        func safeTaskCompletion(bridges: [Bridge], taskName: String) {
            lock.lock()
            defer { lock.unlock() }
            
            print("✅ \(taskName) завершен, найдено: \(bridges.count) мостов")
            
            // Добавляем только уникальные мосты
            let uniqueBridges = bridges.filter { newBridge in
                !allFoundBridges.contains { $0.id == newBridge.id }
            }
            allFoundBridges.append(contentsOf: uniqueBridges)
            
            completedTasks += 1
            
            // Если все задачи завершены, вызываем completion
            if completedTasks >= totalTasks {
                isDiscovering = false
                DispatchQueue.main.async {
                    print("🎯 Найдено всего мостов: \(allFoundBridges.count)")
                    completion(allFoundBridges)
                }
            }
        }
        
        // 1. SSDP Discovery (основной метод)
        ssdpDiscovery { bridges in
            safeTaskCompletion(bridges: bridges, taskName: "SSDP Discovery")
        }
        
        // 2. Cloud Discovery (запасной)
        cloudDiscovery { bridges in
            safeTaskCompletion(bridges: bridges, taskName: "Cloud Discovery")
        }
        
        // 3. IP Scan (последний резерв)
        ipScanDiscovery { bridges in
            safeTaskCompletion(bridges: bridges, taskName: "IP Scan Discovery")
        }
        
        // Таймаут для завершения поиска
        DispatchQueue.global().asyncAfter(deadline: .now() + discoveryTimeout) { [weak self] in
            self?.lock.lock()
            defer { self?.lock.unlock() }
            
            guard let self = self, self.isDiscovering else { return }
            
            self.isDiscovering = false
            DispatchQueue.main.async {
                print("⏰ Таймаут поиска, найдено мостов: \(allFoundBridges.count)")
                completion(allFoundBridges)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// SSDP Discovery - основной метод автономного поиска
    private func ssdpDiscovery(completion: @escaping ([Bridge]) -> Void) {
        print("📡 Запускаем SSDP discovery...")
        
        var foundBridges: [Bridge] = []
        var hasCompleted = false // Флаг для предотвращения множественных вызовов completion
        let ssdpLock = NSLock()
        
        // Безопасный wrapper для completion
        func safeCompletion(_ bridges: [Bridge]) {
            ssdpLock.lock()
            defer { ssdpLock.unlock() }
            
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(bridges)
        }
        
        // Создаем UDP соединение для multicast
        let host = NWEndpoint.Host("239.255.255.250")
        let port = NWEndpoint.Port(1900)
        
        udpConnection = NWConnection(
            host: host,
            port: port,
            using: .udp
        )
        
        // SSDP M-SEARCH запрос для поиска UPnP устройств
        let ssdpRequest = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: upnp:rootdevice\r
        \r
        
        """.data(using: .utf8)!
        
        udpConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("📡 SSDP соединение готово, отправляем запрос...")
                self?.udpConnection?.send(content: ssdpRequest, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ SSDP ошибка отправки: \(error)")
                    } else {
                        print("✅ SSDP запрос отправлен")
                    }
                })
                
                // Слушаем ответы
                self?.receiveSSDP { bridges in
                    ssdpLock.lock()
                    foundBridges.append(contentsOf: bridges)
                    ssdpLock.unlock()
                }
                
            case .failed(let error):
                print("❌ SSDP соединение провалилось: \(error)")
                safeCompletion([])
                
            default:
                break
            }
        }
        
        udpConnection?.start(queue: .global())
        
        // Таймаут для SSDP - гарантированно вызывается один раз
        DispatchQueue.global().asyncAfter(deadline: .now() + 6.0) { [weak self] in
            print("📡 SSDP поиск завершен, найдено: \(foundBridges.count) мостов")
            self?.udpConnection?.cancel()
            safeCompletion(foundBridges)
        }
    }
    
    /// Получение SSDP ответов
    private func receiveSSDP(completion: @escaping ([Bridge]) -> Void) {
        var allBridges: [Bridge] = []
        
        func receiveNext() {
            udpConnection?.receiveMessage { data, context, isComplete, error in
                defer { receiveNext() } // Продолжаем слушать
                
                guard let data = data,
                      let response = String(data: data, encoding: .utf8) else {
                    return
                }
                
                // Проверяем что это ответ от Hue Bridge
                if response.contains("IpBridge") || response.contains("hue") {
                    print("🎯 Найден потенциальный Hue Bridge в SSDP ответе")
                    
                    // Извлекаем URL из LOCATION заголовка
                    if let locationURL = self.extractLocationURL(from: response) {
                        print("📍 LOCATION URL: \(locationURL)")
                        
                        // Проверяем что это точно Hue Bridge
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
    
    /// Извлекаем LOCATION URL из SSDP ответа
    private func extractLocationURL(from response: String) -> String? {
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            if line.lowercased().hasPrefix("location:") {
                return line.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    /// Проверяем что устройство действительно Hue Bridge
    private func validateHueBridge(locationURL: String, completion: @escaping (Bridge?) -> Void) {
        guard let url = URL(string: locationURL) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  error == nil,
                  let xmlString = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            // Проверяем XML содержимое
            if self.isHueBridge(xml: xmlString) {
                let bridgeID = self.extractBridgeID(from: xmlString) ?? "unknown"
                let bridgeName = self.extractBridgeName(from: xmlString) ?? "Philips Hue Bridge"
                let bridgeIP = url.host ?? "unknown"
                
                let bridge = Bridge(
                    id: bridgeID,
                    internalipaddress: bridgeIP,
                    port: url.port ?? 80,
                    name: bridgeName
                )
                
                completion(bridge)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    /// Cloud Discovery через Philips сервис
    private func cloudDiscovery(completion: @escaping ([Bridge]) -> Void) {
        var hasCompleted = false
        let cloudLock = NSLock()
        
        func safeCompletion(_ bridges: [Bridge]) {
            cloudLock.lock()
            defer { cloudLock.unlock() }
            
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(bridges)
        }
        
        guard let url = URL(string: "https://discovery.meethue.com") else {
            safeCompletion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Cloud ошибка: \(error?.localizedDescription ?? "unknown")")
                safeCompletion([])
                return
            }
            
            do {
                let bridges = try JSONDecoder().decode([Bridge].self, from: data)
                print("☁️ Cloud ответил: \(bridges.count) мостов")
                safeCompletion(bridges)
            } catch {
                print("❌ Cloud JSON ошибка: \(error)")
                safeCompletion([])
            }
        }.resume()
        
        // Дополнительный таймаут для безопасности
        DispatchQueue.global().asyncAfter(deadline: .now() + 6.0) {
            safeCompletion([])
        }
    }
    
    /// IP сканирование локальной сети - улучшенная версия
    private func ipScanDiscovery(completion: @escaping ([Bridge]) -> Void) {
        print("🔍 Сканируем популярные IP адреса...")
        
        var hasCompleted = false
        let ipScanLock = NSLock()
        
        func safeCompletion(_ bridges: [Bridge]) {
            ipScanLock.lock()
            defer { ipScanLock.unlock() }
            
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(bridges)
        }
        
        // Расширенный список популярных IP адресов для роутеров
        let commonIPs = [
            // Обычные диапазоны
            "192.168.1.2", "192.168.1.3", "192.168.1.4", "192.168.1.5", "192.168.1.6",
            "192.168.0.2", "192.168.0.3", "192.168.0.4", "192.168.0.5", "192.168.0.6",
            "192.168.0.103", // IP из вашего лога
            "192.168.1.103", "192.168.2.103", "192.168.100.103",
            // Другие популярные диапазоны
            "192.168.100.2", "192.168.100.3", "192.168.86.2", "192.168.86.3",
            "10.0.0.2", "10.0.0.3", "10.0.0.4", "10.0.1.2", "10.0.1.3",
            "172.16.0.2", "172.16.0.3", "172.16.1.2"
        ]
        
        var foundBridges: [Bridge] = []
        var completedIPs = 0
        let totalIPs = commonIPs.count
        
        for ip in commonIPs {
            checkIP(ip) { bridge in
                ipScanLock.lock()
                if let bridge = bridge {
                    foundBridges.append(bridge)
                    print("✅ Найден мост на \(ip): \(bridge.id)")
                }
                
                completedIPs += 1
                
                // Если все IP проверены, завершаем
                if completedIPs >= totalIPs {
                    ipScanLock.unlock()
                    safeCompletion(foundBridges)
                    return
                }
                ipScanLock.unlock()
            }
        }
        
        // Таймаут для IP scan
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            safeCompletion(foundBridges)
        }
    }
    
    /// Проверяет один IP адрес на наличие Hue Bridge - улучшенная версия
    private func checkIP(_ ip: String, completion: @escaping (Bridge?) -> Void) {
        guard let url = URL(string: "http://\(ip)/description.xml") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5 // Быстрее таймаут
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  error == nil,
                  let xmlString = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            // Проверяем что это Hue Bridge
            guard self.isHueBridge(xml: xmlString) else {
                completion(nil)
                return
            }
            
            // Извлекаем ID моста
            let bridgeID = self.extractBridgeID(from: xmlString) ?? "unknown"
            let bridgeName = self.extractBridgeName(from: xmlString) ?? "Philips Hue Bridge"
            
            let bridge = Bridge(
                id: bridgeID,
                internalipaddress: ip,
                port: 80,
                name: bridgeName
            )
            
            completion(bridge)
        }.resume()
    }
    
    /// Проверяет является ли устройство Hue Bridge - улучшенная проверка
    private func isHueBridge(xml: String) -> Bool {
        let lowerXml = xml.lowercased()
        return lowerXml.contains("philips hue") ||
               lowerXml.contains("royal philips") ||
               lowerXml.contains("modelname>philips hue bridge") ||
               lowerXml.contains("ipbridge") ||
               lowerXml.contains("signify") || // Новый владелец Hue
               (lowerXml.contains("manufacturer>royal philips") && lowerXml.contains("hue"))
    }
    
    /// Извлекает ID моста из XML - улучшенное извлечение
    private func extractBridgeID(from xml: String) -> String? {
        // Несколько вариантов поиска ID
        let patterns = [
            "<serialNumber>",
            "<serialnumber>",
            "<UDN>uuid:",
            "<udn>uuid:"
        ]
        
        for pattern in patterns {
            if let start = xml.range(of: pattern, options: .caseInsensitive) {
                let searchStart = start.upperBound
                
                if pattern.contains("uuid:") {
                    // Для UDN ищем до следующего тега
                    if let end = xml.range(of: "</UDN>", options: .caseInsensitive, range: searchStart..<xml.endIndex) {
                        let udn = String(xml[searchStart..<end.lowerBound])
                        // Извлекаем последние 12 символов как bridge ID
                        if udn.count >= 12 {
                            return String(udn.suffix(12))
                        }
                    }
                } else {
                    // Для serialNumber
                    if let end = xml.range(of: "</serialNumber>", options: .caseInsensitive, range: searchStart..<xml.endIndex) {
                        let id = String(xml[searchStart..<end.lowerBound])
                        return id.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        return nil
    }
    
    /// Извлекает имя моста из XML - улучшенное извлечение
    private func extractBridgeName(from xml: String) -> String? {
        let patterns = [
            "<friendlyName>",
            "<friendlyname>",
            "<modelDescription>",
            "<modeldescription>"
        ]
        
        for pattern in patterns {
            if let start = xml.range(of: pattern, options: .caseInsensitive) {
                let searchStart = start.upperBound
                let endPattern = "</" + pattern.dropFirst().dropLast() + ">"
                
                if let end = xml.range(of: endPattern, options: .caseInsensitive, range: searchStart..<xml.endIndex) {
                    let name = String(xml[searchStart..<end.lowerBound])
                    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanName.isEmpty {
                        return cleanName
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        udpConnection?.cancel()
    }
}
