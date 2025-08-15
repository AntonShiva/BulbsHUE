//
//  BridgeRepository.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

/// Repository протокол для работы с мостами
/// Описывает интерфейс для операций с мостами без привязки к конкретной реализации
protocol BridgeRepository {
    
    // MARK: - Bridge Discovery
    
    /// Поиск мостов в локальной сети
    /// - Returns: Publisher с массивом найденных мостов
    func discoverBridges() -> AnyPublisher<[BridgeEntity], Error>
    
    /// Поиск мостов через mDNS (Bonjour)
    /// - Returns: Publisher с массивом найденных мостов
    func discoverBridgesViaMDNS() -> AnyPublisher<[BridgeEntity], Error>
    
    /// Поиск мостов через Philips discovery service
    /// - Returns: Publisher с массивом найденных мостов
    func discoverBridgesViaPhilips() -> AnyPublisher<[BridgeEntity], Error>
    
    // MARK: - Bridge Connection
    
    /// Подключение к мосту
    /// - Parameters:
    ///   - bridge: Мост для подключения
    ///   - forcePairing: Принудительная переавтивизация (для повторного связывания)
    /// - Returns: Publisher с результатом подключения
    func connectToBridge(_ bridge: BridgeEntity, forcePairing: Bool) -> AnyPublisher<BridgeEntity, Error>
    
    /// Аутентификация с мостом (получение Application Key)
    /// - Parameters:
    ///   - bridge: Мост для аутентификации
    ///   - appName: Имя приложения
    ///   - deviceName: Имя устройства
    /// - Returns: Publisher с обновленным мостом (с Application Key)
    func authenticateWithBridge(_ bridge: BridgeEntity, appName: String, deviceName: String) -> AnyPublisher<BridgeEntity, Error>
    
    /// Проверка подключения к мосту
    /// - Parameter bridge: Мост для проверки
    /// - Returns: Publisher с результатом проверки
    func checkBridgeConnection(_ bridge: BridgeEntity) -> AnyPublisher<Bool, Error>
    
    // MARK: - Bridge Info
    
    /// Получение информации о мосте
    /// - Parameter bridge: Мост для получения информации
    /// - Returns: Publisher с обновленной информацией о мосте
    func getBridgeInfo(_ bridge: BridgeEntity) -> AnyPublisher<BridgeEntity, Error>
    
    /// Получение конфигурации моста
    /// - Parameter bridge: Мост для получения конфигурации
    /// - Returns: Publisher с конфигурацией моста
    func getBridgeConfig(_ bridge: BridgeEntity) -> AnyPublisher<BridgeConfig, Error>
    
    /// Получение возможностей моста (лимиты)
    /// - Parameter bridge: Мост для получения возможностей
    /// - Returns: Publisher с возможностями моста
    func getBridgeCapabilities(_ bridge: BridgeEntity) -> AnyPublisher<BridgeCapabilities, Error>
    
    // MARK: - Bridge Storage
    
    /// Сохранение моста в локальное хранилище
    /// - Parameter bridge: Мост для сохранения
    /// - Returns: Publisher с результатом сохранения
    func saveBridge(_ bridge: BridgeEntity) -> AnyPublisher<BridgeEntity, Error>
    
    /// Получение сохраненного моста
    /// - Returns: Publisher с сохраненным мостом (если есть)
    func getSavedBridge() -> AnyPublisher<BridgeEntity?, Never>
    
    /// Удаление сохраненного моста
    /// - Returns: Publisher с результатом удаления
    func removeSavedBridge() -> AnyPublisher<Void, Never>
    
    /// Получение всех сохраненных мостов
    /// - Returns: Publisher с массивом сохраненных мостов
    func getAllSavedBridges() -> AnyPublisher<[BridgeEntity], Never>
}

// MARK: - Repository Errors

/// Ошибки при работе с мостами
enum BridgeRepositoryError: LocalizedError {
    case networkError(Error)
    case noApplicationKey
    case authenticationFailed
    case bridgeNotFound
    case invalidBridgeData
    case connectionTimeout
    case bridgeUnavailable
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .noApplicationKey:
            return "Отсутствует ключ приложения для подключения к мосту"
        case .authenticationFailed:
            return "Не удалось аутентифицироваться с мостом. Убедитесь, что кнопка Link на мосту нажата"
        case .bridgeNotFound:
            return "Мост не найден в сети"
        case .invalidBridgeData:
            return "Некорректные данные моста"
        case .connectionTimeout:
            return "Превышено время ожидания подключения к мосту"
        case .bridgeUnavailable:
            return "Мост недоступен"
        case .invalidResponse:
            return "Получен некорректный ответ от моста"
        }
    }
}
