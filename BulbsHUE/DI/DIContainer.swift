//
//  DIContainer.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Dependency Injection Container
/// Контейнер для управления зависимостями приложения
final class DIContainer {
    static let shared = DIContainer()
    
    // MARK: - Repositories
    private lazy var _lightRepository: LightRepositoryProtocol = {
        // TODO: Создать конкретную реализацию
        return MockLightRepository()
    }()
    
    private lazy var _roomRepository: RoomRepositoryProtocol = {
        // TODO: Создать конкретную реализацию
        return MockRoomRepository()
    }()
    
    private lazy var _bridgeRepository: BridgeRepositoryProtocol = {
        // TODO: Создать конкретную реализацию
        return MockBridgeRepository()
    }()
    
    private lazy var _persistenceRepository: PersistenceRepositoryProtocol = {
        // TODO: Создать конкретную реализацию
        return MockPersistenceRepository()
    }()
    
    // MARK: - Use Cases
    private lazy var _toggleLightUseCase: ToggleLightUseCase = {
        return ToggleLightUseCase(lightRepository: lightRepository)
    }()
    
    private lazy var _updateLightBrightnessUseCase: UpdateLightBrightnessUseCase = {
        return UpdateLightBrightnessUseCase(lightRepository: lightRepository)
    }()
    
    private lazy var _updateLightColorUseCase: UpdateLightColorUseCase = {
        return UpdateLightColorUseCase(lightRepository: lightRepository)
    }()
    
    private lazy var _addLightToEnvironmentUseCase: AddLightToEnvironmentUseCase = {
        return AddLightToEnvironmentUseCase(lightRepository: lightRepository)
    }()
    
    private lazy var _getEnvironmentLightsUseCase: GetEnvironmentLightsUseCase = {
        return GetEnvironmentLightsUseCase(lightRepository: lightRepository)
    }()
    
    private lazy var _searchLightsUseCase: SearchLightsUseCase = {
        return SearchLightsUseCase(lightRepository: lightRepository)
    }()
    
    private lazy var _createRoomWithLightsUseCase: CreateRoomWithLightsUseCase = {
        return CreateRoomWithLightsUseCase(roomRepository: roomRepository, lightRepository: lightRepository)
    }()
    
    // MARK: - Services
    private lazy var _appStore: AppStore = {
        let middlewares: [Middleware] = [
            LoggingMiddleware(),
            // AsyncMiddleware(container: self), // Будет добавлен позже
        ]
        return AppStore(middlewares: middlewares)
    }()
    
    // MARK: - Navigation
    private lazy var _navigationManager: NavigationManager = {
        return NavigationManager.shared
    }()
    
    private init() {}
    
    // MARK: - Public Access
    
    // Repositories
    var lightRepository: LightRepositoryProtocol { _lightRepository }
    var roomRepository: RoomRepositoryProtocol { _roomRepository }
    var bridgeRepository: BridgeRepositoryProtocol { _bridgeRepository }
    var persistenceRepository: PersistenceRepositoryProtocol { _persistenceRepository }
    
    // Use Cases
    var toggleLightUseCase: ToggleLightUseCase { _toggleLightUseCase }
    var updateLightBrightnessUseCase: UpdateLightBrightnessUseCase { _updateLightBrightnessUseCase }
    var updateLightColorUseCase: UpdateLightColorUseCase { _updateLightColorUseCase }
    var addLightToEnvironmentUseCase: AddLightToEnvironmentUseCase { _addLightToEnvironmentUseCase }
    var getEnvironmentLightsUseCase: GetEnvironmentLightsUseCase { _getEnvironmentLightsUseCase }
    var searchLightsUseCase: SearchLightsUseCase { _searchLightsUseCase }
    var createRoomWithLightsUseCase: CreateRoomWithLightsUseCase { _createRoomWithLightsUseCase }
    
    // Services
    var appStore: AppStore { _appStore }
    var navigationManager: NavigationManager { _navigationManager }
}

// MARK: - Logging Middleware
struct LoggingMiddleware: Middleware {
    func process(action: AppAction, state: AppState, store: AppStore) -> AppAction {
        return action
    }
}

// MARK: - Mock Repositories (временные реализации)
final class MockLightRepository: LightRepositoryProtocol {
    private let lightsSubject = CurrentValueSubject<[LightEntity], Never>([])
    
    func getAllLights() -> AnyPublisher<[LightEntity], Error> {
        // Создаем несколько тестовых ламп для демонстрации
        let mockLights = [
            LightEntity(
                id: "1",
                name: "Living Room Table Lamp",
                type: .table,
                subtype: .traditionalLamp,
                isOn: true,
                brightness: 80.0,
                color: LightColor(x: 0.3, y: 0.3),
                colorTemperature: 2700,
                isReachable: true,
                roomId: "living_room_1",
                userSubtype: nil,
                userIcon: nil
            ),
            LightEntity(
                id: "2",
                name: "Kitchen Ceiling Light",
                type: .ceiling,
                subtype: .ceilingRound,
                isOn: false,
                brightness: 100.0,
                color: nil,
                colorTemperature: 4000,
                isReachable: true,
                roomId: "kitchen_1",
                userSubtype: nil,
                userIcon: nil
            )
        ]
        return Just(mockLights).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func getLight(by id: String) -> AnyPublisher<LightEntity?, Error> {
        return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func getAssignedLights() -> AnyPublisher<[LightEntity], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func searchLights(query: String) -> AnyPublisher<[LightEntity], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func updateLightState(id: String, isOn: Bool, brightness: Double?) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func updateLightColor(id: String, color: LightColor) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func updateColorTemperature(id: String, temperature: Int) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func assignLightToEnvironment(id: String, userSubtype: String?, userIcon: String?) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func removeLightFromEnvironment(id: String) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func syncLights() -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    var lightsStream: AnyPublisher<[LightEntity], Never> {
        lightsSubject.eraseToAnyPublisher()
    }
    
    func lightStream(for id: String) -> AnyPublisher<LightEntity?, Never> {
        return Just(nil).eraseToAnyPublisher()
    }
}

final class MockBridgeRepository: BridgeRepositoryProtocol {
    func discoverBridges() -> AnyPublisher<[BridgeEntity], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func connectToBridge(bridge: BridgeEntity) -> AnyPublisher<String, Error> {
        return Just("mock_key").setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func getCurrentBridge() -> AnyPublisher<BridgeEntity?, Error> {
        return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func getBridgeCapabilities() -> AnyPublisher<BridgeCapabilities?, Error> {
        return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}

final class MockRoomRepository: RoomRepositoryProtocol {
    private let roomsSubject = CurrentValueSubject<[RoomEntity], Never>([])
    
    func getAllRooms() -> AnyPublisher<[RoomEntity], Error> {
        let mockRooms = [
            RoomEntity(
                id: "living_room_1",
                name: "Living Room",
                type: .livingRoom,
                lightIds: ["1"],
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            RoomEntity(
                id: "kitchen_1",
                name: "Kitchen",
                type: .kitchen,
                lightIds: ["2"],
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        return Just(mockRooms).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func getRoom(by id: String) -> AnyPublisher<RoomEntity?, Error> {
        return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func getRoomsByType(_ type: RoomType) -> AnyPublisher<[RoomEntity], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func getActiveRooms() -> AnyPublisher<[RoomEntity], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func createRoom(_ room: RoomEntity) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func updateRoom(_ room: RoomEntity) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func deleteRoom(id: String) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func addLightToRoom(roomId: String, lightId: String) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func removeLightFromRoom(roomId: String, lightId: String) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func activateRoom(id: String) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func deactivateRoom(id: String) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    var roomsStream: AnyPublisher<[RoomEntity], Never> {
        roomsSubject.eraseToAnyPublisher()
    }
    
    func roomStream(for id: String) -> AnyPublisher<RoomEntity?, Never> {
        return Just(nil).eraseToAnyPublisher()
    }
}

final class MockPersistenceRepository: PersistenceRepositoryProtocol {
    func saveLightData(_ light: LightEntity) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func loadLightData(id: String) -> AnyPublisher<LightEntity?, Error> {
        return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func loadAllLightData() -> AnyPublisher<[LightEntity], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func deleteLightData(id: String) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func saveSettings<T: Codable>(_ value: T, for key: String) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func loadSettings<T: Codable>(for key: String, type: T.Type) -> AnyPublisher<T?, Error> {
        return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}
