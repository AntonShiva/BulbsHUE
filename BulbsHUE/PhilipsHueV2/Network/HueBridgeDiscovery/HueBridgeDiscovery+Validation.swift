//
//  HueBridgeDiscovery+Validation.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/15/25.
//

import Foundation

@available(iOS 12.0, *)
extension HueBridgeDiscovery {
    
    // MARK: - Bridge Validation Methods
    
    internal func validateHueBridge(locationURL: String, completion: @escaping (Bridge?) -> Void) {
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
    
    internal func checkIPViaConfig(_ ip: String, shouldStop: @escaping () -> Bool = { false }, completion: @escaping (Bridge?) -> Void) {
        guard let url = URL(string: "http://\(ip)/api/0/config"), !shouldStop() else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard !shouldStop() else {
                completion(nil)
                return
            }
            
            if let error = error {
                let nsError = error as NSError
                switch nsError.code {
                case NSURLErrorTimedOut:
                    print("⏰ Таймаут при подключении к \(ip)")
                case NSURLErrorCannotConnectToHost:
                    print("🔌 Не удается подключиться к \(ip)")
                case NSURLErrorNetworkConnectionLost:
                    print("📶 Потеряно сетевое соединение с \(ip)")
                case NSURLErrorNotConnectedToInternet:
                    print("🌐 Нет подключения к интернету")
                default:
                    print("🔍 Ошибка подключения к \(ip): \(error.localizedDescription)")
                }
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔍 /api/0/config неверный ответ от \(ip)")
                completion(nil)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    print("🔍 /api/0/config endpoint не найден на \(ip) (возможно не Hue Bridge)")
                } else {
                    print("🔍 /api/0/config HTTP \(httpResponse.statusCode) на \(ip)")
                }
                completion(nil)
                return
            }
            
            guard let data = data, data.count > 0 else {
                print("🔍 /api/0/config пустой ответ от \(ip)")
                completion(nil)
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("🔍 /api/0/config неверный JSON формат на \(ip)")
                    completion(nil)
                    return
                }
                
                guard let bridgeID = json["bridgeid"] as? String,
                      !bridgeID.isEmpty else {
                    print("🔍 /api/0/config нет bridgeid на \(ip)")
                    completion(nil)
                    return
                }
                
                let name = json["name"] as? String ?? "Philips Hue Bridge"
                let modelID = json["modelid"] as? String
                
                if let modelID = modelID {
                    if !modelID.lowercased().contains("hue") && !modelID.lowercased().contains("bsb") {
                        print("🔍 Устройство на \(ip) не является Hue Bridge (modelid: \(modelID))")
                        completion(nil)
                        return
                    }
                }
                
                let normalizedId = bridgeID.replacingOccurrences(of: ":", with: "").uppercased()
                print("✅ Найден Hue Bridge через /api/0/config на \(ip): \(normalizedId) (\(name))")
                let bridge = Bridge(
                    id: normalizedId,
                    internalipaddress: ip,
                    port: 80,
                    name: name
                )
                completion(bridge)
                
            } catch {
                print("❌ Ошибка парсинга JSON /api/0/config на \(ip): \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    internal func checkIPViaXML(_ ip: String, shouldStop: @escaping () -> Bool = { false }, completion: @escaping (Bridge?) -> Void) {
        guard let url = URL(string: "http://\(ip)/description.xml"), !shouldStop() else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard !shouldStop() else {
                completion(nil)
                return
            }
            
            if let error = error {
                let nsError = error as NSError
                switch nsError.code {
                case NSURLErrorTimedOut:
                    print("⏰ Таймаут description.xml на \(ip)")
                case NSURLErrorCannotConnectToHost:
                    print("🔌 Нет подключения к description.xml на \(ip)")
                default:
                    print("🔍 Ошибка description.xml на \(ip): \(error.localizedDescription)")
                }
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(nil)
                return
            }
            
            guard let data = data,
                  data.count > 0,
                  let xmlString = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            guard self.isHueBridge(xml: xmlString) else {
                completion(nil)
                return
            }
            
            let bridgeID = self.extractBridgeID(from: xmlString) ?? "unknown_\(ip.replacingOccurrences(of: ".", with: "_"))"
            let bridgeName = self.extractBridgeName(from: xmlString) ?? "Philips Hue Bridge"
            
            let normalizedId = bridgeID.replacingOccurrences(of: ":", with: "").uppercased()
            print("✅ Найден Hue Bridge через XML на \(ip): \(normalizedId) (\(bridgeName))")
            let bridge = Bridge(
                id: normalizedId,
                internalipaddress: ip,
                port: 80,
                name: bridgeName
            )
            
            completion(bridge)
        }.resume()
    }
    
    internal func isHueBridge(xml: String) -> Bool {
        let lowerXml = xml.lowercased()
        return lowerXml.contains("philips hue") ||
               lowerXml.contains("royal philips") ||
               lowerXml.contains("modelname>philips hue bridge") ||
               lowerXml.contains("ipbridge") ||
               lowerXml.contains("signify") ||
               (lowerXml.contains("manufacturer>royal philips") && lowerXml.contains("hue")) ||
               (lowerXml.contains("manufacturer>signify") && lowerXml.contains("hue"))
    }
    
    internal func extractBridgeID(from xml: String) -> String? {
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
                    if let end = xml.range(of: "</UDN>", options: .caseInsensitive, range: searchStart..<xml.endIndex) {
                        let udn = String(xml[searchStart..<end.lowerBound])
                        if udn.count >= 12 {
                            return String(udn.suffix(12))
                        }
                    }
                } else {
                    if let end = xml.range(of: "</serialNumber>", options: .caseInsensitive, range: searchStart..<xml.endIndex) {
                        let id = String(xml[searchStart..<end.lowerBound])
                        return id.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        return nil
    }
    
    internal func extractBridgeName(from xml: String) -> String? {
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
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueBridgeDiscovery+Validation.swift
 
 Описание:
 Расширение с методами валидации и проверки найденных устройств.
 Содержит функции для подтверждения что устройство является Hue Bridge.
 
 Основные компоненты:
 - validateHueBridge - валидация через LOCATION URL из SSDP
 - checkIPViaConfig - проверка через /api/0/config endpoint
 - checkIPViaXML - проверка через /description.xml
 - isHueBridge - определение Hue Bridge по XML содержимому
 - extractBridgeID - извлечение ID моста из XML
 - extractBridgeName - извлечение имени моста из XML
 
 Методы проверки:
 1. /api/0/config - основной метод, возвращает JSON с информацией о мосте
 2. /description.xml - резервный метод, UPnP описание устройства
 
 Валидация:
 - Проверка manufacturer (Philips, Signify)
 - Проверка modelid на наличие "hue" или "bsb"
 - Извлечение и нормализация bridge ID
 
 Зависимости:
 - Foundation для URLSession
 - Bridge модель для создания объектов
 
 Связанные файлы:
 - HueBridgeDiscovery.swift - основной класс
 - Все расширения используют эти методы для валидации
 */
