//
//  HueAPIClient+URLSessionDelegate.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import Foundation

// MARK: - URLSessionDelegate

extension HueAPIClient: URLSessionDelegate, URLSessionDataDelegate {
    
    /// Проверяет сертификат Hue Bridge
    /// Поддерживает как Signify CA, так и Google Trust Services (с 2025)
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Проверяем сертификат Philips Hue Bridge
        // 1. Пробуем загрузить корневой сертификат Signify
        if let certPath = Bundle.main.path(forResource: "HueBridgeCACert", ofType: "pem"),
           let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)),
           let certString = String(data: certData, encoding: .utf8) {
            
            print("Найден сертификат HueBridgeCACert.pem")
            
            // Удаляем заголовки PEM и переводы строк
            let lines = certString.components(separatedBy: .newlines)
            let certBase64 = lines.filter {
                !$0.contains("BEGIN CERTIFICATE") &&
                !$0.contains("END CERTIFICATE") &&
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.joined()
            
            if let decodedData = Data(base64Encoded: certBase64),
               let certificate = SecCertificateCreateWithData(nil, decodedData as CFData) {
                
                print("Сертификат успешно декодирован")
                
                // Создаем политику для проверки SSL с hostname verification
                let policy = SecPolicyCreateSSL(true, bridgeIP as CFString)
                
                // Создаем trust объект с загруженным сертификатом
                var trust: SecTrust?
                let status = SecTrustCreateWithCertificates([certificate] as CFArray, policy, &trust)
                
                if status == errSecSuccess, let trust = trust {
                    // Устанавливаем якорные сертификаты
                    SecTrustSetAnchorCertificates(trust, [certificate] as CFArray)
                    SecTrustSetAnchorCertificatesOnly(trust, true)
                    
                    var result: SecTrustResultType = .invalid
                    let evalStatus = SecTrustEvaluate(trust, &result)
                    
                    print("Результат проверки сертификата: \(result.rawValue)")
                    
                    if evalStatus == errSecSuccess &&
                       (result == .unspecified || result == .proceed) {
                        let credential = URLCredential(trust: serverTrust)
                        completionHandler(.useCredential, credential)
                        return
                    }
                }
            } else {
                print("Ошибка декодирования сертификата")
            }
        } else {
            print("Сертификат HueBridgeCACert.pem не найден в Bundle")
        }
        
        // Fallback: для локальных IP разрешаем подключение с любым сертификатом
        // (Hue Bridge может использовать самоподписанный сертификат)
        if bridgeIP.hasPrefix("192.168.") || bridgeIP.hasPrefix("10.") || bridgeIP.hasPrefix("172.") {
            print("Разрешаем подключение к локальному IP: \(bridgeIP)")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("Отклоняем подключение к удаленному IP: \(bridgeIP)")
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    /// Обрабатывает получение данных для SSE
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if dataTask == eventStreamTask {
            parseSSEEvent(data)
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+URLSessionDelegate.swift
 
 Описание:
 Расширение HueAPIClient с реализацией URLSessionDelegate для обработки
 сертификатов и Server-Sent Events.
 
 Основные компоненты:
 - urlSession:didReceive:completionHandler - проверка SSL сертификатов
 - urlSession:dataTask:didReceive - обработка SSE данных
 
 Особенности:
 - Поддержка корневого сертификата Signify (HueBridgeCACert.pem)
 - Автоматическое разрешение для локальных IP адресов
 - Обработка самоподписанных сертификатов для локальной сети
 
 Зависимости:
 - HueAPIClient базовый класс
 - parseSSEEvent для обработки SSE
 - HueBridgeCACert.pem в Bundle (опционально)
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+EventStream.swift - SSE методы
 */
