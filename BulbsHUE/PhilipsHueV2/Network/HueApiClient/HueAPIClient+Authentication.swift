//
//  HueAPIClient+Authentication.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Authentication
    
    /// Создает нового пользователя (application key) на мосту
    /// Требует нажатия кнопки Link на физическом устройстве
    /// - Parameters:
    ///   - appName: Имя приложения для идентификации
    ///   - deviceName: Имя устройства для идентификации
    /// - Returns: Combine Publisher с результатом авторизации
    func createUser(appName: String, deviceName: String) -> AnyPublisher<AuthenticationResponse, Error> {
        guard let url = baseURL?.appendingPathComponent("/api") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "devicetype": "\(appName)#\(deviceName)",
            "generateclientkey": true
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Проверяем статус ответа
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status: \(httpResponse.statusCode)")
                    
                    // В случае ошибки Link Button мост возвращает статус 200, но с ошибкой в теле
                    if httpResponse.statusCode == 200 {
                        return data
                    } else if httpResponse.statusCode == 403 {
                        throw HueAPIError.linkButtonNotPressed
                    }
                }
                throw HueAPIError.invalidResponse
            }
            .decode(type: [AuthenticationResponse].self, decoder: JSONDecoder())
            .compactMap { responses in
                // Philips Hue возвращает массив, берем первый элемент
                responses.first
            }
            .eraseToAnyPublisher()
    }
    
    /// Создает нового пользователя с правильной обработкой локальной сети
    func createUserWithLocalNetworkCheck(appName: String, deviceName: String) -> AnyPublisher<AuthenticationResponse, Error> {
        // Используем HTTP вместо HTTPS для локальной сети
        guard let url = URL(string: "http://\(bridgeIP)/api") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0 // Короткий таймаут для локальной сети
        
        let body = [
            "devicetype": "\(appName)#\(deviceName)",
            "generateclientkey": true
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        // Используем URLSession.shared для локальных запросов
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Логируем ответ для отладки
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 HTTP Status: \(httpResponse.statusCode)")
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📦 Response: \(responseString)")
                    }
                }
                
                return data
            }
            .decode(type: [AuthenticationResponse].self, decoder: JSONDecoder())
            .tryMap { responses in
                // Проверяем ответ
                if let response = responses.first {
                    if let error = response.error {
                        print("❌ Hue API Error: \(error.description ?? "Unknown")")
                        
                        // Код 101 означает что кнопка Link не нажата
                        if error.type == 101 {
                            throw HueAPIError.linkButtonNotPressed
                        } else {
                            throw HueAPIError.httpError(statusCode: error.type ?? 0)
                        }
                    } else if response.success != nil {
                        print("✅ Успешная авторизация!")
                        return response
                    }
                }
                
                throw HueAPIError.invalidResponse
            }
            .eraseToAnyPublisher()
    }
    
    /// Создает нового пользователя (application key) на мосту - версия API v2
    /// В API v2 используется endpoint /api с методом POST
    func createUserV2(appName: String, deviceName: String) -> AnyPublisher<AuthenticationResponse, Error> {
        guard let url = baseURL?.appendingPathComponent("/api") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // В API v2 используется другая структура
        let body: [String: Any] = [
            "devicetype": "\(appName)#\(deviceName)",
            "generateclientkey": true  // Для Entertainment API
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Проверяем статус ответа
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        return data
                    } else if httpResponse.statusCode == 101 {
                        // Link button not pressed
                        throw HueAPIError.linkButtonNotPressed
                    }
                }
                throw HueAPIError.invalidResponse
            }
            .decode(type: [AuthenticationResponse].self, decoder: JSONDecoder())
            .compactMap { $0.first }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Bridge Discovery
    
    /// Поиск Hue Bridge через облачный сервис Philips
    /// - Returns: Combine Publisher со списком найденных мостов
    func discoverBridgesViaCloud() -> AnyPublisher<[Bridge], Error> {
        guard let url = URL(string: "https://discovery.meethue.com") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        // Используем shared session для внешних запросов
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Bridge].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    /// Поиск Hue Bridge через новый SSDP discovery
    /// - Returns: Combine Publisher со списком найденных мостов
    func discoverBridges() -> AnyPublisher<[Bridge], Error> {
        return Future<[Bridge], Error> { promise in
            if #available(iOS 12.0, *) {
                let discovery = HueBridgeDiscovery()
                discovery.discoverBridges { bridges in
                    if bridges.isEmpty {
                        promise(.failure(HueAPIError.bridgeNotFound))
                    } else {
                        promise(.success(bridges))
                    }
                }
            } else {
                // Fallback для старых версий iOS
                promise(.failure(HueAPIError.bridgeNotFound))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Configuration & Capabilities
    
    /// Получает конфигурацию моста
    /// - Returns: Combine Publisher с конфигурацией
    func getBridgeConfig() -> AnyPublisher<BridgeConfig, Error> {
        let endpoint = "/api/0/config"
        return performRequest(endpoint: endpoint, method: "GET", authenticated: false)
    }
    
    /// Получает возможности моста (лимиты ресурсов)
    /// - Returns: Combine Publisher с возможностями
    func getBridgeCapabilities() -> AnyPublisher<BridgeCapabilities, Error> {
        guard applicationKey != nil else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        let endpoint = "/api/\(applicationKey!)/capabilities"
        return performRequest(endpoint: endpoint, method: "GET", authenticated: false)
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+Authentication.swift
 
 Описание:
 Расширение HueAPIClient с методами авторизации и обнаружения мостов.
 
 Основные компоненты:
 - createUser - создание нового пользователя
 - createUserWithLocalNetworkCheck - создание с проверкой локальной сети
 - createUserV2 - создание пользователя API v2
 - discoverBridgesViaCloud - поиск мостов через облако
 - discoverBridges - локальный поиск мостов
 - getBridgeConfig - получение конфигурации
 - getBridgeCapabilities - получение возможностей моста
 
 Зависимости:
 - HueAPIClient базовый класс
 - AuthenticationResponse, Bridge, BridgeConfig, BridgeCapabilities модели
 - HueBridgeDiscovery для локального поиска
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Networking.swift - сетевые методы
 */
