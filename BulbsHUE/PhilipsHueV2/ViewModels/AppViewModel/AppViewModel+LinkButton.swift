//
//  AppViewModel+LinkButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/15/25.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Link Button Handling

extension AppViewModel {
    
    /// Улучшенный метод создания пользователя с правильным ожиданием Link Button
    func createUserWithLinkButtonHandling(
        appName: String = "BulbsHUE",
        onProgress: @escaping (LinkButtonState) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        
        var attemptCount = 0
        let maxAttempts = 30
        var timer: Timer?
        
        print("🔐 Начинаем процесс авторизации с Link Button...")
        
        func attemptAuthorization() {
            attemptCount += 1
            
            onProgress(.waiting(attempt: attemptCount, maxAttempts: maxAttempts))
            
            print("🔐 Попытка #\(attemptCount) создания пользователя...")
            
            if attemptCount > maxAttempts {
                print("⏰ Время ожидания истекло (60 секунд)")
                timer?.invalidate()
                onProgress(.timeout)
                completion(.failure(LinkButtonError.timeout))
                return
            }
            
            createUserRequest(appName: appName, deviceName: deviceName) { [weak self] result in
                switch result {
                case .success(let response):
                    if let success = response.success,
                       let username = success.username {
                        print("✅ Link Button нажата! Пользователь создан!")
                        print("📝 Username: \(username)")
                        
                        timer?.invalidate()
                        
                        self?.applicationKey = username
                        
                        if let clientKey = success.clientkey {
                            print("🔑 Client key получен: \(clientKey)")
                            self?.saveClientKey(clientKey)
                        }
                        
                        self?.connectionStatus = .connected
                        onProgress(.success)
                        completion(.success(username))
                        
                        self?.startEventStream()
                        self?.loadAllData()
                        
                    } else if let error = response.error {
                        self?.handleLinkButtonError(
                            error: error,
                            attemptCount: attemptCount,
                            timer: &timer,
                            onProgress: onProgress,
                            completion: completion,
                            attemptAuthorization: attemptAuthorization
                        )
                    }
                    
                case .failure(let error):
                    print("❌ Сетевая ошибка: \(error)")
                }
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            attemptAuthorization()
        }
        
        attemptAuthorization()
    }
    
    // MARK: - Private Link Button Methods
    
    private func handleLinkButtonError(
        error: AuthError,
        attemptCount: Int,
        timer: inout Timer?,
        onProgress: @escaping (LinkButtonState) -> Void,
        completion: @escaping (Result<String, Error>) -> Void,
        attemptAuthorization: @escaping () -> Void
    ) {
        switch error.type {
        case 101:
            print("⏳ Кнопка Link еще не нажата, ожидаем... (попытка \(attemptCount))")
            
        case 7:
            print("❌ Неверный запрос")
            timer?.invalidate()
            onProgress(.error("Неверный запрос к мосту"))
            completion(.failure(LinkButtonError.invalidRequest))
            
        case 3:
            print("❌ Ресурс недоступен")
            timer?.invalidate()
            onProgress(.error("Мост недоступен"))
            completion(.failure(LinkButtonError.bridgeUnavailable))
            
        default:
            print("⚠️ Неизвестная ошибка: \(error.description ?? "Unknown")")
        }
    }
    
    private func createUserRequest(
        appName: String,
        deviceName: String,
        completion: @escaping (Result<AuthenticationResponse, Error>) -> Void
    ) {
        guard let bridge = currentBridge else {
            completion(.failure(LinkButtonError.noBridgeSelected))
            return
        }
        
        guard let url = URL(string: "http://\(bridge.internalipaddress)/api") else {
            completion(.failure(LinkButtonError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let body: [String: Any] = [
            "devicetype": "\(appName)#\(deviceName)",
            "generateclientkey": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == -1009 {
                        print("🚫 Нет доступа к локальной сети")
                        completion(.failure(LinkButtonError.localNetworkDenied))
                    } else {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let data = data else {
                    completion(.failure(LinkButtonError.noData))
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Ответ моста: \(responseString)")
                }
                
                do {
                    let responses = try JSONDecoder().decode([AuthenticationResponse].self, from: data)
                    if let response = responses.first {
                        completion(.success(response))
                    } else {
                        completion(.failure(LinkButtonError.emptyResponse))
                    }
                } catch {
                    print("❌ Ошибка парсинга: \(error)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// MARK: - Link Button State

enum LinkButtonState {
    case idle
    case waiting(attempt: Int, maxAttempts: Int)
    case success
    case error(String)
    case timeout
    
    var description: String {
        switch self {
        case .idle:
            return "Готов к подключению"
        case .waiting(let attempt, let max):
            return "Ожидание нажатия кнопки (\(attempt)/\(max))"
        case .success:
            return "Подключено успешно!"
        case .error(let message):
            return "Ошибка: \(message)"
        case .timeout:
            return "Время ожидания истекло"
        }
    }
    
    var isConnecting: Bool {
        if case .waiting = self { return true }
        return false
    }
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Link Button Errors

enum LinkButtonError: LocalizedError {
    case notPressed
    case timeout
    case invalidRequest
    case bridgeUnavailable
    case noBridgeSelected
    case invalidURL
    case noData
    case emptyResponse
    case localNetworkDenied
    case unknown(String)
    case tooManyAttempts
    
    var errorDescription: String? {
        switch self {
        case .notPressed:
            return "Кнопка Link не нажата. Нажмите круглую кнопку на Hue Bridge."
        case .timeout:
            return "Время ожидания истекло (60 секунд). Попробуйте снова."
        case .invalidRequest:
            return "Неверный запрос к мосту. Проверьте подключение."
        case .bridgeUnavailable:
            return "Мост недоступен. Проверьте подключение к сети."
        case .noBridgeSelected:
            return "Не выбран мост для подключения."
        case .invalidURL:
            return "Неверный адрес моста."
        case .noData:
            return "Нет данных от моста."
        case .emptyResponse:
            return "Пустой ответ от моста."
        case .localNetworkDenied:
            return "Нет доступа к локальной сети. Разрешите доступ в настройках."
        case .unknown(let message):
            return "Неизвестная ошибка: \(message)"
        case .tooManyAttempts:
            return "Слишком много попыток. Подождите минуту и попробуйте снова"
        }
    }
}
