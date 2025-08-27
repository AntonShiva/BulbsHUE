//
//  LightUseCases.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Base Use Case Protocol
protocol UseCase {
    associatedtype Input
    associatedtype Output
    
    func execute(_ input: Input) -> AnyPublisher<Output, Error>
}

// MARK: - Toggle Light Use Case
struct ToggleLightUseCase: UseCase {
    private let lightRepository: LightRepositoryProtocol
    
    init(lightRepository: LightRepositoryProtocol) {
        self.lightRepository = lightRepository
    }
    
    struct Input {
        let lightId: String
        let brightness: Double? // Если nil, используется последняя запомненная яркость
    }
    
    func execute(_ input: Input) -> AnyPublisher<Void, Error> {
        lightRepository.getLight(by: input.lightId)
            .flatMap { light -> AnyPublisher<Void, Error> in
                guard let light = light else {
                    return Fail(error: LightError.lightNotFound)
                        .eraseToAnyPublisher()
                }
                
                let newState = !light.isOn
                let brightness = input.brightness ?? (newState ? 50.0 : 0.0)
                
                return self.lightRepository.updateLightState(
                    id: input.lightId,
                    isOn: newState,
                    brightness: newState ? brightness : nil
                )
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Update Light Brightness Use Case
struct UpdateLightBrightnessUseCase: UseCase {
    private let lightRepository: LightRepositoryProtocol
    
    init(lightRepository: LightRepositoryProtocol) {
        self.lightRepository = lightRepository
    }
    
    struct Input {
        let lightId: String
        let brightness: Double // 0.0 - 100.0
    }
    
    func execute(_ input: Input) -> AnyPublisher<Void, Error> {
        // Валидация входных данных
        guard input.brightness >= 0.0 && input.brightness <= 100.0 else {
            return Fail(error: LightError.invalidBrightness)
                .eraseToAnyPublisher()
        }
        
        let isOn = input.brightness > 0.0
        
        return lightRepository.updateLightState(
            id: input.lightId,
            isOn: isOn,
            brightness: input.brightness
        )
    }
}

// MARK: - Update Light Color Use Case
struct UpdateLightColorUseCase: UseCase {
    private let lightRepository: LightRepositoryProtocol
    
    init(lightRepository: LightRepositoryProtocol) {
        self.lightRepository = lightRepository
    }
    
    struct Input {
        let lightId: String
        let color: LightColor
    }
    
    func execute(_ input: Input) -> AnyPublisher<Void, Error> {
        // Валидация цветовых координат
        guard input.color.x >= 0.0 && input.color.x <= 1.0 &&
              input.color.y >= 0.0 && input.color.y <= 1.0 else {
            return Fail(error: LightError.invalidColorCoordinates)
                .eraseToAnyPublisher()
        }
        
        return lightRepository.updateLightColor(id: input.lightId, color: input.color)
    }
}

// MARK: - Add Light To Environment Use Case
struct AddLightToEnvironmentUseCase: UseCase {
    private let lightRepository: LightRepositoryProtocol
    
    init(lightRepository: LightRepositoryProtocol) {
        self.lightRepository = lightRepository
    }
    
    struct Input {
        let lightId: String
        let userSubtype: String
        let userIcon: String
    }
    
    func execute(_ input: Input) -> AnyPublisher<Void, Error> {
        // Валидация входных данных
        guard !input.userSubtype.isEmpty else {
            return Fail(error: LightError.invalidUserSubtype)
                .eraseToAnyPublisher()
        }
        
        return lightRepository.assignLightToEnvironment(
            id: input.lightId,
            userSubtype: input.userSubtype,
            userIcon: input.userIcon
        )
    }
}

// MARK: - Get Environment Lights Use Case
struct GetEnvironmentLightsUseCase: UseCase {
    private let lightRepository: LightRepositoryProtocol
    
    init(lightRepository: LightRepositoryProtocol) {
        self.lightRepository = lightRepository
    }
    
    typealias Input = Void
    
    func execute(_ input: Void) -> AnyPublisher<[LightEntity], Error> {
        return lightRepository.getAssignedLights()
    }
}

// MARK: - Search Lights Use Case
struct SearchLightsUseCase: UseCase {
    private let lightRepository: LightRepositoryProtocol
    
    init(lightRepository: LightRepositoryProtocol) {
        self.lightRepository = lightRepository
    }
    
    struct Input {
        let query: String
        let searchType: SearchType
        
        enum SearchType {
            case network
            case serialNumber
        }
    }
    
    func execute(_ input: Input) -> AnyPublisher<[LightEntity], Error> {
        return lightRepository.searchLights(query: input.query)
    }
}

// MARK: - Update Light Type Use Case
struct UpdateLightTypeUseCase: UseCase {
    private let dataPersistenceService: DataPersistenceService
    
    init(dataPersistenceService: DataPersistenceService) {
        self.dataPersistenceService = dataPersistenceService
    }
    
    struct Input {
        let lightId: String
        let userSubtypeName: String
        let userSubtypeIcon: String
    }
    
    func execute(_ input: Input) -> AnyPublisher<Void, Error> {
        // Создаем Future для асинхронного выполнения
        return Future<Void, Error> { promise in
            Task { @MainActor in
                // Получаем текущие данные лампы
                guard let lightData = self.dataPersistenceService.fetchLightData(by: input.lightId) else {
                    promise(.failure(LightError.lightNotFound))
                    return
                }
                
                // Обновляем пользовательский тип и иконку
                lightData.userSubtype = input.userSubtypeName
                lightData.userSubtypeIcon = input.userSubtypeIcon
                lightData.lastUpdated = Date()
                
                // Сохраняем изменения
                self.dataPersistenceService.saveContext()
                
                // Отправляем уведомление об обновлении
                NotificationCenter.default.post(
                    name: Notification.Name("LightDataUpdated"),
                    object: nil,
                    userInfo: [
                        "updateType": "userSubtype",
                        "lightId": input.lightId
                    ]
                )
                
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Update Light Name Use Case
struct UpdateLightNameUseCase: UseCase {
    private let dataPersistenceService: DataPersistenceService
    private let hueAPIClient: HueAPIClient
    
    init(dataPersistenceService: DataPersistenceService, hueAPIClient: HueAPIClient) {
        self.dataPersistenceService = dataPersistenceService
        self.hueAPIClient = hueAPIClient
    }
    
    struct Input {
        let lightId: String
        let newName: String
    }
    
    func execute(_ input: Input) -> AnyPublisher<Void, Error> {
        // Сначала отправляем в Hue API, потом обновляем локальную базу
        let metadata = LightMetadata(name: input.newName)
        
        return hueAPIClient.updateLightMetadata(id: input.lightId, metadata: metadata)
            .flatMap { success -> AnyPublisher<Void, Error> in
                if success {
                    // API успешно обновлен, теперь обновляем локальную базу
                    return self.updateLocalDatabase(lightId: input.lightId, newName: input.newName)
                } else {
                    // Если API не удался, возвращаем ошибку
                    return Fail(error: LightError.apiUpdateFailed)
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Обновляет локальную базу данных после успешного обновления API
    private func updateLocalDatabase(lightId: String, newName: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            Task { @MainActor in
                // Получаем текущие данные лампы
                guard let lightData = self.dataPersistenceService.fetchLightData(by: lightId) else {
                    promise(.failure(LightError.lightNotFound))
                    return
                }
                
                // Обновляем имя лампы в локальной базе
                lightData.name = newName
                lightData.lastUpdated = Date()
                
                // Сохраняем изменения
                self.dataPersistenceService.saveContext()
                
                print("✅ Имя лампы обновлено в локальной базе: \(newName)")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Delete Light Use Case
struct DeleteLightUseCase: UseCase {
    private let lightRepository: LightRepositoryProtocol
    private let dataPersistenceService: DataPersistenceService
    
    init(lightRepository: LightRepositoryProtocol, dataPersistenceService: DataPersistenceService) {
        self.lightRepository = lightRepository
        self.dataPersistenceService = dataPersistenceService
    }
    
    struct Input {
        let lightId: String
        /// Опциональный roomId - если указан, то удаляем лампу из комнаты
        /// Если nil, то полностью удаляем лампу из Environment
        let roomId: String?
    }
    
    func execute(_ input: Input) -> AnyPublisher<Void, Error> {
        if let roomId = input.roomId {
            // Удаляем лампу только из комнаты, оставляем в Environment
            return lightRepository.getLight(by: input.lightId)
                .flatMap { light -> AnyPublisher<Void, Error> in
                    guard light != nil else {
                        return Fail(error: LightError.lightNotFound)
                            .eraseToAnyPublisher()
                    }
                    
                    // Удаляем из комнаты через LightRepository 
                    return self.lightRepository.removeLightFromEnvironment(id: input.lightId)
                }
                .eraseToAnyPublisher()
        } else {
            // Полностью удаляем лампу из Environment
            return Future<Void, Error> { promise in
                Task { @MainActor in
                    // Сначала проверяем, что лампа существует
                    guard let lightData = self.dataPersistenceService.fetchLightData(by: input.lightId) else {
                        promise(.failure(LightError.lightNotFound))
                        return
                    }
                    
                    // Удаляем из локальной базы данных
                    self.dataPersistenceService.deleteLightData(input.lightId)
                    
                    // Отправляем уведомление об обновлении
                    NotificationCenter.default.post(
                        name: Notification.Name("LightDataDeleted"),
                        object: nil,
                        userInfo: ["lightId": input.lightId]
                    )
                    
                    print("✅ Лампа '\(lightData.name ?? input.lightId)' полностью удалена из Environment")
                    promise(.success(()))
                }
            }
            .flatMap { _ -> AnyPublisher<Void, Error> in
                // После успешного удаления из локальной базы, удаляем из repository
                return self.lightRepository.removeLightFromEnvironment(id: input.lightId)
            }
            .eraseToAnyPublisher()
        }
    }
}

// MARK: - Light Errors
enum LightError: Error, LocalizedError {
    case lightNotFound
    case invalidBrightness
    case apiUpdateFailed
    case invalidColorCoordinates
    case invalidUserSubtype
    case networkError
    case deviceNotReachable
    
    var errorDescription: String? {
        switch self {
        case .lightNotFound:
            return "Лампа не найдена"
        case .invalidBrightness:
            return "Недопустимое значение яркости"
        case .apiUpdateFailed:
            return "Не удалось обновить данные в Hue Bridge"
        case .invalidColorCoordinates:
            return "Недопустимые цветовые координаты"
        case .invalidUserSubtype:
            return "Недопустимый пользовательский тип"
        case .networkError:
            return "Ошибка сети"
        case .deviceNotReachable:
            return "Устройство недоступно"
        }
    }
}
