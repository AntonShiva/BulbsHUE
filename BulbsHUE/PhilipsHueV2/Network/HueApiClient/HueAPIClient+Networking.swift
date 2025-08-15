//
//  HueAPIClient+Networking.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Network Request Methods
    
    /// Выполняет HTTP запрос к API
    /// - Parameters:
    ///   - endpoint: Путь к endpoint'у
    ///   - method: HTTP метод
    ///   - body: Тело запроса (опционально)
    ///   - authenticated: Требуется ли аутентификация (по умолчанию true)
    /// - Returns: Combine Publisher с декодированным ответом
    internal func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: Data? = nil,
        authenticated: Bool = true
    ) -> AnyPublisher<T, Error> {
        if authenticated {
            guard let applicationKey = applicationKey else {
                print("❌ Нет application key для аутентифицированного запроса")
                return Fail(error: HueAPIError.notAuthenticated)
                    .eraseToAnyPublisher()
            }
        }
        
        guard let url = baseURL?.appendingPathComponent(endpoint) else {
            print("❌ Невозможно создать URL: baseURL=\(baseURL?.absoluteString ?? "nil"), endpoint=\(endpoint)")
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        print("📤 HTTP \(method) запрос: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if authenticated, let applicationKey = applicationKey {
            request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
            print("🔑 Добавлен заголовок hue-application-key: \(String(applicationKey.prefix(8)))...")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
            print("📦 Тело запроса: \(String(data: body, encoding: .utf8) ?? "не удалось декодировать")")
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Ответ не является HTTP ответом")
                    throw HueAPIError.invalidResponse
                }
                
                print("📥 HTTP \(httpResponse.statusCode) ответ от \(url.absoluteString)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Тело ответа: \(responseString)")
                } else {
                    print("📄 Тело ответа: данные не декодируются как строка (\(data.count) байт)")
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    print("❌ HTTP ошибка \(httpResponse.statusCode)")
                    
                    // Проверяем специфичные ошибки
                    if httpResponse.statusCode == 403 {
                        print("🚫 403 Forbidden - возможно нужно нажать кнопку link на мосту")
                        throw HueAPIError.linkButtonNotPressed
                    } else if httpResponse.statusCode == 503 {
                        print("⚠️ 503 Service Unavailable - буфер мостa переполнен")
                        throw HueAPIError.bufferFull
                    } else if httpResponse.statusCode == 429 {
                        print("⏱ 429 Too Many Requests - превышен лимит запросов")
                        throw HueAPIError.rateLimitExceeded
                    } else if httpResponse.statusCode == 404 {
                        print("🔍 404 Not Found - endpoint не существует")
                        print("   Проверьте поддержку API v2 на мосту")
                    } else if httpResponse.statusCode == 401 {
                        print("🔐 401 Unauthorized - проблема с аутентификацией")
                        print("   Проверьте application key")
                    }
                    
                    throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                }
                
                print("✅ HTTP запрос успешен")
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .catch { error in
                if error is DecodingError {
                    print("❌ Ошибка декодирования JSON: \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("   Данные повреждены: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("   Ключ не найден: \(key.stringValue) в \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("   Неправильный тип: ожидался \(type), контекст: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("   Значение не найдено: \(type), контекст: \(context.debugDescription)")
                        @unknown default:
                            print("   Неизвестная ошибка декодирования")
                        }
                    }
                }
                return Fail<T, Error>(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// ИСПРАВЛЕННАЯ версия performRequest для API v2 (HTTPS)
    internal func performRequestHTTPS<T: Decodable>(
        endpoint: String,
        method: String,
        body: Data? = nil,
        authenticated: Bool = true
    ) -> AnyPublisher<T, Error> {
        
        guard authenticated else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let applicationKey = applicationKey else {
            print("❌ Нет application key для HTTPS запроса")
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = baseURLHTTPS?.appendingPathComponent(endpoint) else {
            print("❌ Невозможно создать HTTPS URL: endpoint=\(endpoint)")
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        print("📤 HTTPS \(method) запрос: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: API v2 использует hue-application-key header
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        print("🔑 Установлен hue-application-key: \(String(applicationKey.prefix(8)))...")
        
        if let body = body {
            request.httpBody = body
            if let bodyString = String(data: body, encoding: .utf8) {
                print("📦 HTTPS тело запроса: \(bodyString)")
            }
        }
        
        return sessionHTTPS.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ HTTPS ответ не является HTTP ответом")
                    throw HueAPIError.invalidResponse
                }
                
                print("📥 HTTPS \(httpResponse.statusCode) ответ от \(url.absoluteString)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 HTTPS тело ответа: \(responseString)")
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    print("❌ HTTPS ошибка \(httpResponse.statusCode)")
                    
                    switch httpResponse.statusCode {
                    case 401:
                        print("🔐 401 Unauthorized - проблема с application key")
                        throw HueAPIError.notAuthenticated
                    case 403:
                        print("🚫 403 Forbidden - возможно нужна повторная авторизация")
                        throw HueAPIError.linkButtonNotPressed
                    case 404:
                        print("🔍 404 Not Found - неверный endpoint API v2")
                        throw HueAPIError.invalidURL
                    case 503:
                        print("⚠️ 503 Service Unavailable - мост перегружен")
                        throw HueAPIError.bufferFull
                    case 429:
                        print("⏱ 429 Too Many Requests - превышен лимит")
                        throw HueAPIError.rateLimitExceeded
                    default:
                        break
                    }
                    
                    throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                }
                
                print("✅ HTTPS запрос успешен")
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Communication Status Management
    
    /// Проверяет ошибки связи в ответе API и обновляет статус лампы
    internal func checkCommunicationErrors(lightId: String, response: GenericResponse) {
        guard let errors = response.errors, !errors.isEmpty else {
            // Нет ошибок - лампа в сети
            updateLightCommunicationStatus(lightId: lightId, status: .online)
            return
        }
        
        for error in errors {
            if let description = error.description {
                print("[HueAPIClient] Ошибка для лампы \(lightId): \(description)")
                
                if description.contains("communication issues") ||
                   description.contains("command may not have effect") ||
                   description.contains("device unreachable") ||
                   description.contains("unreachable") {
                    updateLightCommunicationStatus(lightId: lightId, status: .issues)
                    return
                }
            }
        }
        
        // Если есть ошибки, но не связанные со связью
        updateLightCommunicationStatus(lightId: lightId, status: .online)
    }
    
    /// Обновляет статус связи лампы в LightsViewModel (в памяти)
    internal func updateLightCommunicationStatus(lightId: String, status: CommunicationStatus) {
        DispatchQueue.main.async { [weak self] in
            print("[HueAPIClient] Обновляем статус связи лампы \(lightId): \(status)")
            
            // Обновляем статус в LightsViewModel для мгновенного отклика UI
            if let lightsViewModel = self?.lightsViewModel {
                lightsViewModel.updateLightCommunicationStatus(lightId: lightId, status: status)
                print("[HueAPIClient] ✅ Статус связи обновлен в LightsViewModel")
            } else {
                print("[HueAPIClient] ⚠️ LightsViewModel недоступен для обновления статуса")
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Выполняет batch операцию для множественных изменений
    func batchUpdate(updates: [BatchUpdate]) -> AnyPublisher<BatchResponse, Error> {
        let endpoint = "/clip/v2/resource"
        
        let body = BatchRequest(data: updates)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(body)
            
            return performRequestHTTPS<BatchResponse>(endpoint: endpoint, method: "PUT", body: data)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Удаляет ресурс
    func deleteResource<T: Decodable>(type: String, id: String) -> AnyPublisher<T, Error> {
        let endpoint = "/clip/v2/resource/\(type)/\(id)"
        return performRequestHTTPS<T>(endpoint: endpoint, method: "DELETE")
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+Networking.swift
 
 Описание:
 Расширение HueAPIClient с методами для выполнения сетевых запросов.
 Содержит общие методы для HTTP/HTTPS запросов и управления статусом связи.
 
 Основные компоненты:
 - performRequest - базовый метод HTTP запросов
 - performRequestHTTPS - метод для HTTPS запросов API v2
 - checkCommunicationErrors - проверка ошибок связи
 - updateLightCommunicationStatus - обновление статуса связи
 - batchUpdate - batch операции
 - deleteResource - удаление ресурсов
 
 Зависимости:
 - HueAPIClient базовый класс
 - GenericResponse, BatchUpdate, BatchResponse модели
 - HueAPIError для обработки ошибок
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Models.swift - модели данных
 */
