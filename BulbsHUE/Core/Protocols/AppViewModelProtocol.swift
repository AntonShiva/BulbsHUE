//
//  AppViewModelProtocol.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 9/05/25.
//

import Foundation
import Combine

/// Protocol abstraction for AppViewModel dependencies
/// Следует принципу Dependency Inversion Principle (DIP) из SOLID

/// Enum определяющий статус подключения к мосту Philips Hue
enum ConnectionStatus: Equatable {
    case disconnected
    case searching
    case connecting
    case connected
    case needsAuthentication
    case discovered
    case error(String)
    
    static func ==(lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.searching, .searching),
             (.connecting, .connecting),
             (.connected, .connected),
             (.needsAuthentication, .needsAuthentication),
             (.discovered, .discovered):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

@MainActor
protocol AppViewModelProtocol: AnyObject {
    
    // MARK: - Published Properties
    
    /// Статус подключения к мосту Philips Hue
    var connectionStatus: ConnectionStatus { get }
    var connectionStatusPublisher: AnyPublisher<ConnectionStatus, Never> { get }
    
    /// Обнаруженные мосты Philips Hue в сети
    var discoveredBridges: [Bridge] { get }
    var discoveredBridgesPublisher: AnyPublisher<[Bridge], Never> { get }
    
    /// Текущий выбранный мост
    var currentBridge: Bridge? { get set }
    
    /// Ошибки подключения и работы с API
    var error: Error? { get }
    var errorPublisher: AnyPublisher<Error?, Never> { get }
    
    /// Управление отображением экрана настройки
    var showSetup: Bool { get set }
    
    // MARK: - Bridge Discovery Methods
    
    /// Начать поиск мостов в сети
    func searchForBridges()
    
    /// Подключиться к выбранному мосту
    /// - Parameter bridge: Мост для подключения
    func connectToBridge(_ bridge: Bridge)
    
    // MARK: - Authentication Methods
    
    /// Создать пользователя на мосту с обработкой Link Button
    /// - Parameters:
    ///   - appName: Имя приложения для регистрации
    ///   - onProgress: Обработчик прогресса подключения
    ///   - completion: Обработчик результата подключения
    func createUserWithLinkButtonHandling(
        appName: String,
        onProgress: @escaping (LinkButtonState) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    )
    
    /// Создать пользователя на мосту с повторными попытками
    /// - Parameters:
    ///   - appName: Имя приложения для регистрации
    ///   - completion: Обработчик результата подключения
    func createUserWithRetry(
        appName: String,
        completion: @escaping (Bool) -> Void
    )
}

// MARK: - AppViewModel Extension

/// Расширение AppViewModel для соответствия протоколу
extension AppViewModel: AppViewModelProtocol {
    
    var connectionStatusPublisher: AnyPublisher<ConnectionStatus, Never> {
        // @Observable не поддерживает publishers, возвращаем Just publisher
        Just(connectionStatus).eraseToAnyPublisher()
    }
    
    var discoveredBridgesPublisher: AnyPublisher<[Bridge], Never> {
        // @Observable не поддерживает publishers, возвращаем Just publisher
        Just(discoveredBridges).eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<Error?, Never> {
        // @Observable не поддерживает publishers, возвращаем Just publisher
        Just(error).eraseToAnyPublisher()
    }
}