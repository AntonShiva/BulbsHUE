//
//  NetworkDiagnostics.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 13.08.2025.
//

import Foundation
import Network
import SystemConfiguration

/// Утилита для диагностики сетевых проблем при обнаружении Hue Bridge
class NetworkDiagnostics {
    
    /// Проверяет доступность интернета
    static func isInternetAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return isReachable && !needsConnection
    }
    
    /// Получает информацию о текущем сетевом подключении
    static func getCurrentNetworkInfo() -> String {
        var info = "📶 Сетевая диагностика:\n"
        
        // Проверяем доступность интернета
        let internetAvailable = isInternetAvailable()
        info += "🌐 Интернет: \(internetAvailable ? "✅ доступен" : "❌ недоступен")\n"
        
        // Получаем IP адрес устройства
        if let deviceIP = SmartBridgeDiscovery.getCurrentDeviceIP() {
            info += "📱 IP устройства: \(deviceIP)\n"
            
            // Определяем подсеть
            let subnet = extractSubnet(from: deviceIP)
            info += "🏠 Подсеть: \(subnet)\n"
        } else {
            info += "📱 IP устройства: ❌ не определен\n"
        }
        
        // Проверяем Wi-Fi
        info += "📡 Wi-Fi: \(isConnectedToWiFi() ? "✅ подключен" : "❌ не подключен")\n"
        
        return info
    }
    
    /// Извлекает подсеть из IP адреса
    private static func extractSubnet(from ip: String) -> String {
        let components = ip.components(separatedBy: ".")
        if components.count >= 3 {
            return "\(components[0]).\(components[1]).\(components[2]).x"
        }
        return "неизвестно"
    }
    
    /// Проверяет подключение к Wi-Fi
    private static func isConnectedToWiFi() -> Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        SCNetworkReachabilityGetFlags(reachability, &flags)
        
        return flags.contains(.reachable) && !flags.contains(.isWWAN)
    }
    
    /// Проверяет конкретный IP адрес на отзывчивость
    static func pingHost(_ host: String, completion: @escaping (Bool, TimeInterval?) -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let url = URL(string: "http://\(host)") else {
            completion(false, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.httpMethod = "HEAD" // Быстрая проверка
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            
            if error == nil, let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode < 500, responseTime)
            } else {
                completion(false, nil)
            }
        }.resume()
    }
    
    /// Тестирует доступность облачного сервиса Philips
    static func testPhilipsCloudService(completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "https://discovery.meethue.com") else {
            completion(false, "Невозможно создать URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            
            if let error = error {
                completion(false, "Ошибка: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Неверный ответ сервера")
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let data = data, data.count > 0 {
                    completion(true, "✅ Сервис доступен (время ответа: \(String(format: "%.2f", responseTime))с)")
                } else {
                    completion(false, "Пустой ответ от сервиса")
                }
            } else {
                completion(false, "HTTP \(httpResponse.statusCode)")
            }
        }.resume()
    }
    
    /// Генерирует подробный отчет о сетевой диагностике
    static func generateDiagnosticReport(completion: @escaping (String) -> Void) {
        var report = "🔍 ДИАГНОСТИКА СЕТИ HUE BRIDGE\n"
        report += "=" * 40 + "\n\n"
        
        // Базовая информация о сети
        report += getCurrentNetworkInfo() + "\n"
        
        // Тестируем облачный сервис
        testPhilipsCloudService { success, message in
            report += "☁️ Philips Cloud: \(message)\n\n"
            
            // Тестируем популярные IP адреса
            let testIPs = ["192.168.1.1", "192.168.0.1", "10.0.0.1"]
            var completedTests = 0
            
            report += "🏠 ТЕСТ ЛОКАЛЬНОЙ СЕТИ:\n"
            
            for ip in testIPs {
                pingHost(ip) { success, responseTime in
                    if success, let time = responseTime {
                        report += "✅ \(ip) отвечает (\(String(format: "%.0f", time * 1000))ms)\n"
                    } else {
                        report += "❌ \(ip) недоступен\n"
                    }
                    
                    completedTests += 1
                    if completedTests == testIPs.count {
                        report += "\n📋 РЕКОМЕНДАЦИИ:\n"
                        
                        if !isInternetAvailable() {
                            report += "• Проверьте интернет-соединение\n"
                        }
                        
                        if !isConnectedToWiFi() {
                            report += "• Убедитесь что устройство подключено к Wi-Fi\n"
                        }
                        
                        report += "• Попробуйте перезагрузить Hue Bridge\n"
                        report += "• Убедитесь что Bridge и телефон в одной сети\n"
                        report += "• Проверьте настройки роутера (multicast/UPnP)\n"
                        
                        completion(report)
                    }
                }
            }
        }
    }
}

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
