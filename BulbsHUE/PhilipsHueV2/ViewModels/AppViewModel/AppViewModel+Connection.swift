//
//  AppViewModel+Connection.swift
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

// MARK: - Bridge Connection

extension AppViewModel {
    
    /// Подключается к выбранному мосту
    func connectToBridge(_ bridge: Bridge) {
        currentBridge = bridge
        UserDefaults.standard.set(bridge.internalipaddress, forKey: "HueBridgeIP")
        
        recreateAPIClient(with: bridge.internalipaddress)
        
        apiClient.getBridgeConfig()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.connectionStatus = .disconnected
                    }
                },
                receiveValue: { [weak self] config in
                    if let apiVersion = config.apiversion,
                       apiVersion.compare("1.46.0", options: .numeric) == .orderedAscending {
                        self?.error = HueAPIError.outdatedBridge
                        return
                    }
                    
                    if let bridgeId = config.bridgeid {
                        self?.currentBridge?.id = bridgeId
                    }
                    
                    if let key = self?.applicationKey {
                        self?.connectionStatus = .connected
                        self?.startEventStream()
                        self?.loadAllData()
                        self?.showSetup = false
                    } else {
                        self?.connectionStatus = .needsAuthentication
                        self?.showSetup = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Создает нового пользователя на мосту
    func createUser(appName: String, completion: @escaping (Bool) -> Void) {
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        
        apiClient.createUser(appName: appName, deviceName: deviceName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        if case HueAPIError.linkButtonNotPressed = error {
                            completion(false)
                        } else {
                            completion(false)
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    if let success = response.success,
                       let username = success.username {
                        self?.applicationKey = username
                        
                        if let clientKey = success.clientkey {
                            UserDefaults.standard.set(clientKey, forKey: "HueClientKey")
                            self?.setupEntertainmentClient(clientKey: clientKey)
                        }
                        self?.connectionStatus = .connected
                        self?.showSetup = false
                        self?.startEventStream()
                        self?.loadAllData()
                        completion(true)
                    } else if let error = response.error {
                        if error.type == 101 {
                            self?.error = HueAPIError.linkButtonNotPressed
                        }
                        completion(false)
                    } else {
                        completion(false)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Создание пользователя на конкретном мосту
    func createUser(on bridge: Bridge, appName: String, deviceName: String, completion: @escaping (Bool) -> Void) {
        if currentBridge?.id != bridge.id {
            connectToBridge(bridge)
        }
        createUser(appName: appName, completion: completion)
    }
    
    /// Создает пользователя с обработкой локальной сети
    func createUserWithRetry(appName: String, completion: @escaping (Bool) -> Void) {
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        
        guard let bridge = currentBridge else {
            print("❌ Нет выбранного моста")
            completion(false)
            return
        }
        
        print("🔐 Попытка создания пользователя на мосту: \(bridge.internalipaddress)")
        
        apiClient.createUserWithLocalNetworkCheck(appName: appName, deviceName: deviceName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        print("❌ Ошибка создания пользователя: \(error)")
                        
                        if let nsError = error as NSError?,
                           nsError.code == -1009 {
                            print("🚫 Нет доступа к локальной сети!")
                            self.error = HueAPIError.localNetworkPermissionDenied
                        } else if case HueAPIError.linkButtonNotPressed = error as? HueAPIError ?? HueAPIError.invalidResponse {
                            print("⏳ Кнопка Link еще не нажата")
                        }
                        
                        completion(false)
                    }
                },
                receiveValue: { [weak self] response in
                    if let success = response.success,
                       let username = success.username {
                        print("✅ Пользователь создан! Username: \(username)")
                        
                        self?.applicationKey = username
                        
                        if let clientKey = success.clientkey {
                            print("🔑 Client key: \(clientKey)")
                            if let bridgeId = self?.currentBridge?.id {
                                _ = HueKeychainManager.shared.saveClientKey(clientKey, for: bridgeId)
                            }
                            self?.setupEntertainmentClient(clientKey: clientKey)
                        }
                        
                        self?.connectionStatus = .connected
                        self?.showSetup = false
                        self?.startEventStream()
                        self?.loadAllData()
                        self?.saveCredentials()
                        
                        completion(true)
                    } else {
                        print("❌ Неожиданный ответ от API")
                        completion(false)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Создает пользователя с улучшенной обработкой ошибок
    func createUserEnhanced(appName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        
        apiClient.createUser(appName: appName, deviceName: deviceName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        if let hueError = error as? HueAPIError {
                            switch hueError {
                            case .linkButtonNotPressed:
                                completion(.failure(LinkButtonError.notPressed))
                            case .httpError(let statusCode):
                                if statusCode == 429 {
                                    completion(.failure(LinkButtonError.tooManyAttempts))
                                } else {
                                    completion(.failure(error))
                                }
                            default:
                                completion(.failure(error))
                            }
                        } else {
                            completion(.failure(error))
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    if let success = response.success,
                       let username = success.username {
                        self?.applicationKey = username
                        
                        if let clientKey = success.clientkey {
                            self?.setupEntertainmentClient(clientKey: clientKey)
                        }
                        
                        self?.connectionStatus = .connected
                        self?.showSetup = false
                        self?.startEventStream()
                        self?.loadAllData()
                        self?.saveCredentials()
                        
                        completion(.success(true))
                    } else if let error = response.error {
                        switch error.type {
                        case 101:
                            completion(.failure(LinkButtonError.notPressed))
                        case 7:
                            completion(.failure(LinkButtonError.invalidRequest))
                        default:
                            completion(.failure(LinkButtonError.unknown(error.description ?? "Unknown error")))
                        }
                    } else {
                        completion(.failure(LinkButtonError.unknown("No response")))
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Подключение к мосту с использованием Touch Link
    func connectWithTouchLink(bridge: Bridge, completion: @escaping (Bool) -> Void) {
        connectToBridge(bridge)
        
        var attempts = 0
        let maxAttempts = 10
        
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { timer in
            attempts += 1
            
            self.createUser(appName: "PhilipsHueV2") { success in
                if success {
                    timer.invalidate()
                    completion(true)
                } else if attempts >= maxAttempts {
                    timer.invalidate()
                    completion(false)
                }
            }
        }
    }
    
    /// Загружает информацию о возможностях моста
    func loadBridgeCapabilities() {
        apiClient.getBridgeCapabilities()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] capabilities in
                    self?.bridgeCapabilities = capabilities
                    self?.checkResourceLimits(capabilities)
                }
            )
            .store(in: &cancellables)
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ AppViewModel+Connection.swift
 
 Описание:
 Расширение AppViewModel для управления подключением к Hue Bridge.
 Обрабатывает создание пользователя, проверку версии API и управление сессией.
 
 Основные компоненты:
 - connectToBridge() - подключение к выбранному мосту
 - createUser() - базовое создание пользователя
 - createUserEnhanced() - создание с детальной обработкой ошибок
 - createUserWithRetry() - создание с повторными попытками
 - connectWithTouchLink() - альтернативное подключение Touch Link
 - loadBridgeCapabilities() - загрузка информации о возможностях моста
 
 Использование:
 appViewModel.connectToBridge(bridge)
 appViewModel.createUser(appName: "MyApp") { success in ... }
 appViewModel.createUserEnhanced(appName: "MyApp") { result in ... }
 
 Зависимости:
 - HueAPIClient для API запросов
 - HueKeychainManager для сохранения credentials
 - HueEntertainmentClient для Entertainment API
 
 Связанные файлы:
 - AppViewModel.swift - основной класс
 - AppViewModel+LinkButton.swift - специальная обработка Link Button
 - AppViewModel+Keychain.swift - сохранение учетных данных
 */
