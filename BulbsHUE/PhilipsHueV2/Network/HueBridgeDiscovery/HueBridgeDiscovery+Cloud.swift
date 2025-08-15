//
//  HueBridgeDiscovery+Cloud.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/15/25.
//

import Foundation

@available(iOS 12.0, *)
extension HueBridgeDiscovery {
    
    // MARK: - Cloud Discovery
    
    internal func cloudDiscovery(completion: @escaping ([Bridge]) -> Void) {
        print("☁️ Запускаем Cloud Discovery...")
        
        var hasCompleted = false
        let cloudLock = NSLock()
        
        func safeCompletion(_ bridges: [Bridge]) {
            cloudLock.lock()
            defer { cloudLock.unlock() }
            
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(bridges)
        }
        
        func attemptCloudDiscovery(attempt: Int, maxAttempts: Int = 3) {
            guard attempt <= maxAttempts else {
                print("❌ Cloud Discovery: исчерпаны все попытки (\(maxAttempts))")
                safeCompletion([])
                return
            }
            
            print("☁️ Cloud Discovery попытка \(attempt)/\(maxAttempts)")
            
            guard let url = URL(string: "https://discovery.meethue.com") else {
                print("❌ Невозможно создать URL для Cloud Discovery")
                safeCompletion([])
                return
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse {
                    print("☁️ Cloud HTTP статус: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode != 200 {
                        print("❌ Cloud HTTP ошибка: \(httpResponse.statusCode)")
                        
                        if httpResponse.statusCode >= 500 || httpResponse.statusCode == 408 {
                            DispatchQueue.global().asyncAfter(deadline: .now() + Double(attempt)) {
                                attemptCloudDiscovery(attempt: attempt + 1, maxAttempts: maxAttempts)
                            }
                            return
                        }
                    }
                }
                
                guard let data = data else {
                    if let error = error {
                        print("❌ Cloud ошибка сети: \(error.localizedDescription)")
                        
                        if (error as NSError).code == NSURLErrorTimedOut ||
                           (error as NSError).code == NSURLErrorCannotConnectToHost ||
                           (error as NSError).code == NSURLErrorNetworkConnectionLost {
                            DispatchQueue.global().asyncAfter(deadline: .now() + Double(attempt)) {
                                attemptCloudDiscovery(attempt: attempt + 1, maxAttempts: maxAttempts)
                            }
                            return
                        }
                    }
                    safeCompletion([])
                    return
                }
                
                guard data.count > 0 else {
                    print("❌ Cloud вернул пустой ответ")
                    safeCompletion([])
                    return
                }
                
                let dataString = String(data: data, encoding: .utf8) ?? "binary data"
                print("☁️ Cloud ответ (первые 200 символов): \(String(dataString.prefix(200)))")
                
                if !dataString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") &&
                   !dataString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                    print("❌ Cloud ответ не является JSON: \(dataString)")
                    safeCompletion([])
                    return
                }
                
                do {
                    let bridges = try JSONDecoder().decode([Bridge].self, from: data)
                    print("✅ Cloud Discovery успешен: \(bridges.count) мостов")
                    for bridge in bridges {
                        print("   - \(bridge.name ?? "Unknown") (\(bridge.id)) at \(bridge.internalipaddress)")
                    }
                    safeCompletion(bridges)
                } catch {
                    print("❌ Cloud JSON ошибка: \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("   - Data corrupted: \(context.debugDescription)")
                            if let underlyingError = context.underlyingError {
                                print("   - Underlying error: \(underlyingError)")
                            }
                        case .keyNotFound(let key, let context):
                            print("   - Key not found: \(key), context: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("   - Type mismatch: \(type), context: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("   - Value not found: \(type), context: \(context.debugDescription)")
                        @unknown default:
                            print("   - Unknown decoding error")
                        }
                    }
                    
                    if attempt < maxAttempts {
                        DispatchQueue.global().asyncAfter(deadline: .now() + Double(attempt * 2)) {
                            attemptCloudDiscovery(attempt: attempt + 1, maxAttempts: maxAttempts)
                        }
                    } else {
                        safeCompletion([])
                    }
                }
            }.resume()
        }
        
        attemptCloudDiscovery(attempt: 1)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 25.0) {
            safeCompletion([])
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueBridgeDiscovery+Cloud.swift
 
 Описание:
 Расширение для поиска Hue Bridge через облачный сервис Philips.
 Использует официальный API discovery.meethue.com для поиска мостов.
 
 Основные компоненты:
 - cloudDiscovery - метод поиска через облако
 - attemptCloudDiscovery - рекурсивная функция с retry логикой
 - Обработка HTTP ошибок и retry механизм
 
 API:
 - Endpoint: https://discovery.meethue.com
 - Возвращает JSON массив с информацией о мостах в локальной сети
 - Автоматический retry при временных ошибках (5xx, timeout)
 
 Особенности:
 - До 3 попыток подключения с экспоненциальной задержкой
 - Валидация JSON ответа перед парсингом
 - Детальная диагностика ошибок декодирования
 
 Зависимости:
 - Foundation для URLSession
 - Bridge модель для декодирования JSON
 
 Связанные файлы:
 - HueBridgeDiscovery.swift - основной класс
 - Bridge.swift - модель данных моста
 */
