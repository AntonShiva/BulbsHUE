//
//  HueBridgeDiscovery.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 31.07.2025.
//

import Foundation

/// Простой и рабочий класс для поиска Philips Hue Bridge
/// Основан на реальных рабочих примерах с GitHub
class HueBridgeDiscovery {
    
    // MARK: - Public Methods
    
    /// Главный метод поиска - простой и надежный
    func discoverBridges(completion: @escaping ([Bridge]) -> Void) {
        print("🔍 Запускаем поиск Hue Bridge...")
        
        // Сначала пробуем Cloud Discovery (быстро)
        cloudDiscovery { [weak self] cloudBridges in
            if !cloudBridges.isEmpty {
                print("✅ Cloud нашел \(cloudBridges.count) мостов")
                completion(cloudBridges)
                return
            }
            
            // Если Cloud не дал результата, сканируем IP
            print("🔍 Cloud не нашел мостов, сканируем локальную сеть...")
            self?.ipScanDiscovery { ipBridges in
                print("✅ IP scan завершен: найдено \(ipBridges.count) мостов")
                completion(ipBridges)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Cloud Discovery через Philips сервис
    private func cloudDiscovery(completion: @escaping ([Bridge]) -> Void) {
        guard let url = URL(string: "https://discovery.meethue.com") else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Cloud ошибка: \(error?.localizedDescription ?? "unknown")")
                completion([])
                return
            }
            
            do {
                let bridges = try JSONDecoder().decode([Bridge].self, from: data)
                print("☁️ Cloud ответил: \(bridges.count) мостов")
                completion(bridges)
            } catch {
                print("❌ Cloud JSON ошибка: \(error)")
                completion([])
            }
        }.resume()
    }
    
    /// IP сканирование локальной сети
    private func ipScanDiscovery(completion: @escaping ([Bridge]) -> Void) {
        print("🔍 Сканируем популярные IP адреса...")
        
        // Популярные IP адреса для роутеров
        let commonIPs = [
            "192.168.1.2", "192.168.1.3", "192.168.1.4", "192.168.1.5",
            "192.168.0.2", "192.168.0.3", "192.168.0.4", "192.168.0.5",
            "192.168.100.2", "192.168.100.3",
            "10.0.0.2", "10.0.0.3",
            "172.16.0.2", "172.16.0.3"
        ]
        
        var foundBridges: [Bridge] = []
        let group = DispatchGroup()
        let lock = NSLock()
        
        for ip in commonIPs {
            group.enter()
            checkIP(ip) { bridge in
                if let bridge = bridge {
                    lock.lock()
                    foundBridges.append(bridge)
                    print("✅ Найден мост на \(ip): \(bridge.id)")
                    lock.unlock()
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(foundBridges)
        }
    }
    
    /// Проверяет один IP адрес на наличие Hue Bridge
    private func checkIP(_ ip: String, completion: @escaping (Bridge?) -> Void) {
        guard let url = URL(string: "http://\(ip)/description.xml") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
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
    
    /// Проверяет является ли устройство Hue Bridge
    private func isHueBridge(xml: String) -> Bool {
        return xml.contains("Philips hue") ||
               xml.contains("Royal Philips") ||
               xml.contains("modelName>Philips hue bridge")
    }
    
    /// Извлекает ID моста из XML
    private func extractBridgeID(from xml: String) -> String? {
        // Ищем <serialNumber>
        if let start = xml.range(of: "<serialNumber>"),
           let end = xml.range(of: "</serialNumber>") {
            let id = String(xml[start.upperBound..<end.lowerBound])
            return id.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    /// Извлекает имя моста из XML  
    private func extractBridgeName(from xml: String) -> String? {
        // Ищем <friendlyName>
        if let start = xml.range(of: "<friendlyName>"),
           let end = xml.range(of: "</friendlyName>") {
            let name = String(xml[start.upperBound..<end.lowerBound])
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}