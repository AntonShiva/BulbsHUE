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

// MARK: - Light Errors
enum LightError: Error, LocalizedError {
    case lightNotFound
    case invalidBrightness
    case invalidColorCoordinates
    case invalidUserSubtype
    case networkError
    case deviceNotReachable
    
    var errorDescription: String? {
        switch self {
        case .lightNotFound:
            return "Лампа не найдена"
        case .invalidBrightness:
            return "Неверное значение яркости (должно быть от 0 до 100)"
        case .invalidColorCoordinates:
            return "Неверные цветовые координаты"
        case .invalidUserSubtype:
            return "Не указан тип лампы"
        case .networkError:
            return "Ошибка сети"
        case .deviceNotReachable:
            return "Устройство недоступно"
        }
    }
}
