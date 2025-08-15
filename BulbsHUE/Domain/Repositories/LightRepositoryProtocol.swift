//
//  LightRepository.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Light Repository Protocol
/// Протокол репозитория для работы с лампами
/// Определяет контракт без зависимости от конкретной реализации
protocol LightRepositoryProtocol {
    // MARK: - Queries
    /// Получить все лампы
    func getAllLights() -> AnyPublisher<[LightEntity], Error>
    
    /// Получить лампу по ID
    func getLight(by id: String) -> AnyPublisher<LightEntity?, Error>
    
    /// Получить назначенные в Environment лампы
    func getAssignedLights() -> AnyPublisher<[LightEntity], Error>
    
    /// Поиск ламп по критериям
    func searchLights(query: String) -> AnyPublisher<[LightEntity], Error>
    
    // MARK: - Commands
    /// Обновить состояние лампы
    func updateLightState(id: String, isOn: Bool, brightness: Double?) -> AnyPublisher<Void, Error>
    
    /// Обновить цвет лампы
    func updateLightColor(id: String, color: LightColor) -> AnyPublisher<Void, Error>
    
    /// Обновить цветовую температуру
    func updateColorTemperature(id: String, temperature: Int) -> AnyPublisher<Void, Error>
    
    /// Назначить лампу в Environment
    func assignLightToEnvironment(id: String, userSubtype: String?, userIcon: String?) -> AnyPublisher<Void, Error>
    
    /// Убрать лампу из Environment
    func removeLightFromEnvironment(id: String) -> AnyPublisher<Void, Error>
    
    /// Синхронизировать с удаленным источником
    func syncLights() -> AnyPublisher<Void, Error>
    
    // MARK: - Reactive Streams
    /// Поток обновлений ламп в реальном времени
    var lightsStream: AnyPublisher<[LightEntity], Never> { get }
    
    /// Поток обновлений конкретной лампы
    func lightStream(for id: String) -> AnyPublisher<LightEntity?, Never>
}
