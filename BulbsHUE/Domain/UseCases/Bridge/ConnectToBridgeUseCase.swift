//
//  ConnectToBridgeUseCase.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

/// Use Case для подключения к мосту Philips Hue
/// Обрабатывает весь процесс подключения включая аутентификацию
class ConnectToBridgeUseCase {
    
    // MARK: - Dependencies
    
    private let bridgeRepository: BridgeRepository
    
    // MARK: - Private Properties
    
    private let appName = "BulbsHUE"
    private let deviceName = "iOS Device"
    
    // MARK: - Initialization
    
    init(bridgeRepository: BridgeRepository) {
        self.bridgeRepository = bridgeRepository
    }
    
    // MARK: - Public Methods
    
    /// Подключение к мосту с автоматической аутентификацией
    /// - Parameters:
    ///   - bridge: Мост для подключения
    ///   - forceReconnect: Принудительное переподключение
    /// - Returns: Publisher с подключенным мостом
    func execute(bridge: BridgeEntity, forceReconnect: Bool = false) -> AnyPublisher<BridgeEntity, Error> {
        print("🔗 [ConnectToBridgeUseCase] Подключаемся к мосту: \(bridge.name) (\(bridge.ipAddress))")
        
        // Сначала проверяем подключение
        return bridgeRepository.checkBridgeConnection(bridge)
            .flatMap { [weak self] isConnected -> AnyPublisher<BridgeEntity, Error> in
                guard let self = self else {
                    return Fail(error: BridgeRepositoryError.bridgeNotFound)
                        .eraseToAnyPublisher()
                }
                
                // Если мост недоступен, возвращаем ошибку
                if !isConnected {
                    print("❌ [ConnectToBridgeUseCase] Мост недоступен")
                    return Fail(error: BridgeRepositoryError.bridgeUnavailable)
                        .eraseToAnyPublisher()
                }
                
                // Если уже подключены и есть ключ приложения, не переподключаемся
                if !forceReconnect && bridge.applicationKey != nil && bridge.isConnected {
                    print("✅ [ConnectToBridgeUseCase] Уже подключены к мосту")
                    return Just(bridge)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // Нужна аутентификация
                print("🔐 [ConnectToBridgeUseCase] Требуется аутентификация")
                return self.authenticateAndConnect(bridge: bridge)
            }
            .eraseToAnyPublisher()
    }
    
    /// Принудительное переподключение к мосту
    /// - Parameter bridge: Мост для переподключения
    /// - Returns: Publisher с переподключенным мостом
    func forceReconnect(bridge: BridgeEntity) -> AnyPublisher<BridgeEntity, Error> {
        return execute(bridge: bridge, forceReconnect: true)
    }
    
    // MARK: - Private Methods
    
    /// Выполняет аутентификацию и подключение
    /// - Parameter bridge: Мост для аутентификации
    /// - Returns: Publisher с аутентифицированным мостом
    private func authenticateAndConnect(bridge: BridgeEntity) -> AnyPublisher<BridgeEntity, Error> {
        return bridgeRepository.authenticateWithBridge(
            bridge, 
            appName: appName, 
            deviceName: deviceName
        )
        .flatMap { [weak self] authenticatedBridge -> AnyPublisher<BridgeEntity, Error> in
            guard let self = self else {
                return Fail(error: BridgeRepositoryError.bridgeNotFound)
                    .eraseToAnyPublisher()
            }
            
            // Получаем дополнительную информацию о мосту
            return self.bridgeRepository.getBridgeInfo(authenticatedBridge)
                .map { updatedBridge in
                    // Создаем финальную версию bridge entity с полной информацией
                    BridgeEntity(
                        id: updatedBridge.id,
                        name: updatedBridge.name,
                        ipAddress: updatedBridge.ipAddress,
                        modelId: updatedBridge.modelId,
                        swVersion: updatedBridge.swVersion,
                        applicationKey: authenticatedBridge.applicationKey,
                        isConnected: true,
                        lastSeen: Date()
                    )
                }
                .eraseToAnyPublisher()
        }
        .flatMap { [weak self] finalBridge -> AnyPublisher<BridgeEntity, Error> in
            guard let self = self else {
                return Fail(error: BridgeRepositoryError.bridgeNotFound)
                    .eraseToAnyPublisher()
            }
            
            // Сохраняем подключенный мост
            return self.bridgeRepository.saveBridge(finalBridge)
        }
        .eraseToAnyPublisher()
    }
}
