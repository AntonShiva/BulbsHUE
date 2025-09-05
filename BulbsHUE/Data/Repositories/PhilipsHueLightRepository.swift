//
//  PhilipsHueLightRepository.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 18.08.2025.
//

import Foundation
import Combine
import SwiftUI

/// Реальная реализация LightRepository, работающая с Philips Hue API
/// через AppViewModel
final class PhilipsHueLightRepository: LightRepositoryProtocol {
    
    // MARK: - Dependencies
    
    /// Слабая ссылка на AppViewModel для получения реальных данных ламп
    private weak var appViewModel: AppViewModel?
    
    /// DataPersistenceService для работы с локальными данными
    private weak var dataPersistenceService: DataPersistenceService?
    
    // MARK: - Initialization
    
    init(appViewModel: AppViewModel, dataPersistenceService: DataPersistenceService) {
        self.appViewModel = appViewModel
        self.dataPersistenceService = dataPersistenceService
    }
    
    // MARK: - LightRepositoryProtocol Implementation
    
    func getAllLights() -> AnyPublisher<[LightEntity], Error> {
        guard let appViewModel = appViewModel else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // Преобразуем Light из API в LightEntity
        let lightEntities = appViewModel.lightsViewModel.lights.compactMap { light in
            convertToLightEntity(light)
        }
        
        return Just(lightEntities)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getLight(by id: String) -> AnyPublisher<LightEntity?, Error> {
        guard let appViewModel = appViewModel else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // Ищем лампу в списке API ламп
        if let light = appViewModel.lightsViewModel.lights.first(where: { $0.id == id }) {
            let lightEntity = convertToLightEntity(light)
            return Just(lightEntity)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Just(nil)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    func getAssignedLights() -> AnyPublisher<[LightEntity], Error> {
        guard let dataPersistenceService = dataPersistenceService else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // ✅ ИСПРАВЛЕНО: Преобразуем Light в LightEntity
        let lightEntities = dataPersistenceService.assignedLights.compactMap { light in
            convertToLightEntity(light)
        }
        
        return Just(lightEntities)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func searchLights(query: String) -> AnyPublisher<[LightEntity], Error> {
        return getAllLights()
            .map { lights in
                lights.filter { light in
                    light.name.localizedCaseInsensitiveContains(query)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func updateLightState(id: String, isOn: Bool, brightness: Double?) -> AnyPublisher<Void, Error> {
        guard let appViewModel = appViewModel else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // ✅ ИСПРАВЛЕНО: Используем правильные методы LightsViewModel
        guard let light = appViewModel.lightsViewModel.lights.first(where: { $0.id == id }) else {
            return Fail(error: LightRepositoryError.lightNotFound)
                .eraseToAnyPublisher()
        }
        
        // Устанавливаем состояние питания
        appViewModel.lightsViewModel.setPower(for: light, on: isOn)
        
        // Устанавливаем яркость если указана
        if let brightness = brightness {
            appViewModel.lightsViewModel.setBrightness(for: light, brightness: brightness)
        }
        
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func updateLightColor(id: String, color: LightColor) -> AnyPublisher<Void, Error> {
        guard let appViewModel = appViewModel else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // ✅ ИСПРАВЛЕНО: Используем правильные методы LightsViewModel
        guard let light = appViewModel.lightsViewModel.lights.first(where: { $0.id == id }) else {
            return Fail(error: LightRepositoryError.lightNotFound)
                .eraseToAnyPublisher()
        }
        
        // Преобразуем LightColor в SwiftUI.Color
        let swiftUIColor = Color(.sRGB, red: Double(color.x), green: Double(color.y), blue: 0.5)
        appViewModel.lightsViewModel.setColor(for: light, color: swiftUIColor)
        
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func updateColorTemperature(id: String, temperature: Int) -> AnyPublisher<Void, Error> {
        guard let appViewModel = appViewModel else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // ✅ ИСПРАВЛЕНО: Используем правильные методы LightsViewModel
        guard let light = appViewModel.lightsViewModel.lights.first(where: { $0.id == id }) else {
            return Fail(error: LightRepositoryError.lightNotFound)
                .eraseToAnyPublisher()
        }
        
        appViewModel.lightsViewModel.setColorTemperature(for: light, temperature: temperature)
        
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func assignLightToEnvironment(id: String, userSubtype: String?, userIcon: String?) -> AnyPublisher<Void, Error> {
        guard let dataPersistenceService = dataPersistenceService else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // ✅ ИСПРАВЛЕНО: Используем правильные методы DataPersistenceService
        dataPersistenceService.assignLightToEnvironment(id)
        
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func removeLightFromEnvironment(id: String) -> AnyPublisher<Void, Error> {
        guard let dataPersistenceService = dataPersistenceService else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // ✅ ИСПРАВЛЕНО: Используем правильные методы DataPersistenceService
        dataPersistenceService.removeLightFromEnvironment(id)
        
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func syncLights() -> AnyPublisher<Void, Error> {
        guard let appViewModel = appViewModel else {
            return Fail(error: LightRepositoryError.noConnection)
                .eraseToAnyPublisher()
        }
        
        // Перезагружаем лампы из API
        appViewModel.lightsViewModel.loadLights()
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    var lightsStream: AnyPublisher<[LightEntity], Never> {
        guard let appViewModel = appViewModel else {
            return Just([]).eraseToAnyPublisher()
        }
        
        // @Observable не поддерживает publishers, возвращаем текущее состояние
        return Just(appViewModel.lightsViewModel.lights)
            .map { lights in
                lights.compactMap { light in
                    self.convertToLightEntity(light)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func lightStream(for id: String) -> AnyPublisher<LightEntity?, Never> {
        return lightsStream
            .map { lights in
                lights.first { $0.id == id }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    /// Преобразует Light из API в LightEntity
    /// - Parameter light: Лампа из Philips Hue API
    /// - Returns: LightEntity или nil если конвертация невозможна
    private func convertToLightEntity(_ light: Light) -> LightEntity? {
        // Определяем тип и подтип лампы на основе пользовательских настроек или архетипа
        let lightType: LightType
        let lightSubtype: LightSubtype?
        
        if let userSubtypeName = light.metadata.userSubtypeName {
            // Пользователь уже настроил подтип
            lightSubtype = LightSubtype.allCases.first { $0.displayName.uppercased() == userSubtypeName.uppercased() }
            lightType = lightSubtype?.parentType ?? .other
        } else {
            // Используем общий тип до настройки пользователем
            lightType = .other
            lightSubtype = nil
        }
        
        return LightEntity(
            id: light.id,
            name: light.metadata.name,
            type: lightType,
            subtype: lightSubtype,
            isOn: light.on.on,
            brightness: Double(light.dimming?.brightness ?? 0),
            color: light.color?.xy.map { LightColor(x: $0.x, y: $0.y) },
            colorTemperature: light.color_temperature?.mirek,
            isReachable: light.isReachable,
            roomId: nil, // Комната определяется отдельно
            userSubtype: light.metadata.userSubtypeName,
            userIcon: light.metadata.userSubtypeIcon
        )
    }
}

// MARK: - Errors

enum LightRepositoryError: Error, LocalizedError {
    case noConnection
    case lightNotFound
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No connection to Philips Hue bridge"
        case .lightNotFound:
            return "Light not found"
        case .updateFailed:
            return "Failed to update light"
        }
    }
}
