//
//  SmartBridgeDiscovery.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 13.08.2025.
//

import Foundation
import Network

#if canImport(Darwin)
import Darwin
#endif

/// Интеллектуальное обнаружение Hue Bridge через анализ сетевой инфраструктуры
class SmartBridgeDiscovery {
    
    /// Получает список вероятных устройств в локальной сети
    static func getLocalNetworkDevices() -> [String] {
        guard let deviceIP = getCurrentDeviceIP() else {
            print("❌ Не удается получить IP устройства для сканирования")
            return []
        }
        
        let components = deviceIP.components(separatedBy: ".")
        guard components.count == 4 else {
            return []
        }
        
        let subnet = "\(components[0]).\(components[1]).\(components[2])"
        var devices: [String] = []
        
        // Добавляем наиболее вероятные адреса для Hue Bridge:
        let commonLastOctets = [
            1,   // Роутер
            2, 3, 4, 5, 6, 7, 8, 9, 10,  // Первые устройства
            20, 21, 22, 23, 24, 25,       // Популярные адреса
            50, 51, 52, 53, 54, 55,       // Средний диапазон
            100, 101, 102, 103, 104, 105, // DHCP диапазон многих роутеров
            200, 201, 202, 203, 204, 205  // Статические адреса
        ]
        
        for octet in commonLastOctets {
            let ip = "\(subnet).\(octet)"
            if ip != deviceIP {
                devices.append(ip)
            }
        }
        
        print("🔍 Сгенерировано \(devices.count) приоритетных адресов для сканирования в подсети \(subnet).x")
        return devices
    }
    
    /// Получает IP адрес роутера через сетевые интерфейсы
    static func getDefaultGateway() -> String? {
        // На iOS мы можем попытаться определить gateway через системные вызовы
        // или через анализ IP адреса устройства
        
        guard let deviceIP = getCurrentDeviceIP() else {
            return nil
        }
        
        let components = deviceIP.components(separatedBy: ".")
        guard components.count == 4 else {
            return nil
        }
        
        // Предполагаем что gateway обычно .1 в подсети
        let possibleGateway = "\(components[0]).\(components[1]).\(components[2]).1"
        
        print("🌐 Предполагаемый gateway: \(possibleGateway)")
        return possibleGateway
    }
    
    /// Получает подсеть на основе IP устройства и маски сети
    static func getSubnetRange() -> [String] {
        guard let deviceIP = getCurrentDeviceIP(),
              let gateway = getDefaultGateway() else {
            return []
        }
        
        // Определяем подсеть из IP устройства
        let deviceComponents = deviceIP.components(separatedBy: ".")
        let gatewayComponents = gateway.components(separatedBy: ".")
        
        guard deviceComponents.count == 4, gatewayComponents.count == 4 else {
            return []
        }
        
        // Используем первые 3 октета как базу подсети
        let subnet = "\(deviceComponents[0]).\(deviceComponents[1]).\(deviceComponents[2])"
        
        var subnetIPs: [String] = []
        
        // Сканируем диапазон .1-.254 (исключая broadcast)
        for i in 1...254 {
            let ip = "\(subnet).\(i)"
            if ip != deviceIP { // Исключаем собственный IP
                subnetIPs.append(ip)
            }
        }
        
        print("🏠 Сгенерирован диапазон подсети \(subnet).x: \(subnetIPs.count) адресов")
        return subnetIPs
    }
    
    /// Находит Hue Bridge используя интеллектуальные методы
    static func discoverBridgeIntelligently(completion: @escaping ([Bridge]) -> Void) {
        print("🧠 Запускаем интеллектуальное обнаружение Hue Bridge...")
        
        var foundBridges: [Bridge] = []
        var completedSteps = 0
        let totalSteps = 3
        let lock = NSLock()
        
        func stepCompleted(bridges: [Bridge], stepName: String) {
            lock.lock()
            defer { lock.unlock() }
            
            print("✅ \(stepName): найдено \(bridges.count) мостов")
            
            // Добавляем уникальные мосты
            for bridge in bridges {
                if !foundBridges.contains(where: { $0.id == bridge.id }) {
                    foundBridges.append(bridge)
                }
            }
            
            completedSteps += 1
            
            if completedSteps >= totalSteps {
                print("🎯 Интеллектуальное обнаружение завершено: \(foundBridges.count) уникальных мостов")
                completion(foundBridges)
            }
        }
        
        // Шаг 1: Проверяем приоритетные адреса в текущей подсети
        let priorityDevices = getLocalNetworkDevices()
        checkMultipleIPs(priorityDevices) { bridges in
            stepCompleted(bridges: bridges, stepName: "Priority Subnet Scan")
        }
        
        // Шаг 2: Проверяем диапазон вокруг предполагаемого роутера
        if let gateway = getDefaultGateway() {
            let gatewayRange = generateNearbyIPs(around: gateway, count: 20)
            checkMultipleIPs(gatewayRange) { bridges in
                stepCompleted(bridges: bridges, stepName: "Gateway Range Scan")
            }
        } else {
            stepCompleted(bridges: [], stepName: "Gateway Range Scan")
        }
        
        // Шаг 3: Попробуем найти через Bonjour/mDNS
        if #available(iOS 14.0, *) {
            attemptBonjourDiscovery { bridges in
                stepCompleted(bridges: bridges, stepName: "Bonjour Discovery")
            }
        } else {
            stepCompleted(bridges: [], stepName: "Bonjour Discovery")
        }
        
        // Таймаут на случай зависания
        DispatchQueue.global().asyncAfter(deadline: .now() + 15.0) { // Уменьшен таймаут
            if completedSteps < totalSteps {
                print("⏰ Таймаут интеллектуального обнаружения")
                completion(foundBridges)
            }
        }
    }
    
    /// Генерирует IP адреса рядом с заданным адресом
    static func generateNearbyIPs(around centerIP: String, count: Int) -> [String] {
        let components = centerIP.components(separatedBy: ".")
        guard components.count == 4,
              let lastOctet = Int(components[3]) else {
            return []
        }
        
        let subnet = "\(components[0]).\(components[1]).\(components[2])"
        var nearbyIPs: [String] = []
        
        // Генерируем адреса выше и ниже центрального
        let range = count / 2
        for offset in -range...range {
            let newOctet = lastOctet + offset
            if newOctet > 0 && newOctet < 255 {
                nearbyIPs.append("\(subnet).\(newOctet)")
            }
        }
        
        return nearbyIPs
    }
    
    /// Проверяет несколько IP адресов параллельно
    static func checkMultipleIPs(_ ips: [String], completion: @escaping ([Bridge]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var foundBridges: [Bridge] = []
        let bridgeLock = NSLock()
        
        for ip in ips {
            dispatchGroup.enter()
            
            checkSingleIP(ip) { bridge in
                if let bridge = bridge {
                    bridgeLock.lock()
                    foundBridges.append(bridge)
                    bridgeLock.unlock()
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .global()) {
            completion(foundBridges)
        }
    }
    
    /// Проверяет один IP адрес на наличие Hue Bridge
    static func checkSingleIP(_ ip: String, completion: @escaping (Bridge?) -> Void) {
        guard let url = URL(string: "http://\(ip)/api/0/config") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  error == nil else {
                completion(nil)
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let bridgeID = json["bridgeid"] as? String,
                      !bridgeID.isEmpty else {
                    completion(nil)
                    return
                }
                
                let name = json["name"] as? String ?? "Philips Hue Bridge"
                
                // Дополнительная проверка что это точно Hue Bridge
                if let modelID = json["modelid"] as? String {
                    let validModels = ["BSB001", "BSB002", "BSB003", "Hue Bridge"]
                    if !validModels.contains(where: { modelID.contains($0) }) {
                        completion(nil)
                        return
                    }
                }
                
                print("✅ Интеллектуально найден Hue Bridge на \(ip): \(bridgeID)")
                let bridge = Bridge(
                    id: bridgeID,
                    internalipaddress: ip,
                    port: 80,
                    name: name
                )
                completion(bridge)
                
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    /// Пытается найти мост через Bonjour/mDNS
    @available(iOS 14.0, *)
    static func attemptBonjourDiscovery(completion: @escaping ([Bridge]) -> Void) {
        print("📡 Попытка Bonjour/mDNS обнаружения...")
        
        let browser = NWBrowser(for: .bonjour(type: "_hue._tcp", domain: nil), using: .tcp)
        var foundBridges: [Bridge] = []
        
        browser.browseResultsChangedHandler = { results, changes in
            for result in results {
                if case .service(let name, let type, let domain, _) = result.endpoint {
                    print("📡 mDNS найден сервис: \(name).\(type)\(domain)")
                    // В реальной реализации здесь нужно было бы resolve IP адрес
                    // Это требует дополнительной работы с NWConnection
                }
            }
        }
        
        browser.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("📡 mDNS браузер готов")
            case .failed(let error):
                print("❌ mDNS ошибка: \(error)")
                completion([])
            default:
                break
            }
        }
        
        browser.start(queue: .global())
        
        // Короткий таймаут для mDNS
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            browser.cancel()
            completion(foundBridges)
        }
    }
    
    /// Получает IP адрес текущего устройства
    static func getCurrentDeviceIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" { // WiFi интерфейс
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                  &hostname, socklen_t(hostname.count),
                                  nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
}
