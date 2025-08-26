//
//  DIContainer.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine
import SwiftData

// MARK: - Dependency Injection Container
/// Контейнер для управления зависимостями приложения
final class DIContainer {
    static let shared = DIContainer()
    
    // MARK: - Repositories
    private lazy var _lightRepository: LightRepositoryProtocol = {
        // ✅ ИСПРАВЛЕНО: Используем реальный репозиторий вместо mock
        // Создаем через фабричный метод, который будет установлен извне
        return _lightRepositoryFactory?() ?? MockLightRepository()
    }()
    
    /// Фабрика для создания LightRepository с реальными зависимостями
    private var _lightRepositoryFactory: (() -> LightRepositoryProtocol)?
    
    /// Фабрика для создания RoomRepository с реальными зависимостями
    private var _roomRepositoryFactory: (() -> RoomRepositoryProtocol)?
    
    private lazy var _roomRepository: RoomRepositoryProtocol = {
        // ✅ Используем реальный репозиторий вместо mock
        return _roomRepositoryFactory?() ?? MockRoomRepository()
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
    
    private lazy var _getRoomsUseCase: GetRoomsUseCase = {
        return GetRoomsUseCase(roomRepository: roomRepository)
    }()
    
    private lazy var _deleteRoomUseCase: DeleteRoomUseCase = {
        return DeleteRoomUseCase(roomRepository: roomRepository)
    }()
    
    private lazy var _moveLightBetweenRoomsUseCase: MoveLightBetweenRoomsUseCase = {
        return MoveLightBetweenRoomsUseCase(roomRepository: roomRepository, lightRepository: lightRepository)
    }()
    
    private lazy var _removeLightFromRoomUseCase: RemoveLightFromRoomUseCase = {
        return RemoveLightFromRoomUseCase(roomRepository: roomRepository)
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
    var getRoomsUseCase: GetRoomsUseCase { _getRoomsUseCase }
    var deleteRoomUseCase: DeleteRoomUseCase { _deleteRoomUseCase }
    var moveLightBetweenRoomsUseCase: MoveLightBetweenRoomsUseCase { _moveLightBetweenRoomsUseCase }
    var removeLightFromRoomUseCase: RemoveLightFromRoomUseCase { _removeLightFromRoomUseCase }
    
    // Services
    var appStore: AppStore { _appStore }
    var navigationManager: NavigationManager { _navigationManager }
    
    // MARK: - Configuration
    
    /// Настройка реального LightRepository с зависимостями
    /// - Parameters:
    ///   - appViewModel: AppViewModel с данными Philips Hue API
    ///   - dataPersistenceService: Сервис для работы с локальными данными
    func configureLightRepository(appViewModel: AppViewModel, dataPersistenceService: DataPersistenceService) {
        _lightRepositoryFactory = {
            PhilipsHueLightRepository(
                appViewModel: appViewModel,
                dataPersistenceService: dataPersistenceService
            )
        }
        
        // Принудительно пересоздаем зависимые Use Cases
        _lightRepository = _lightRepositoryFactory!()
        _toggleLightUseCase = ToggleLightUseCase(lightRepository: _lightRepository)
        _updateLightBrightnessUseCase = UpdateLightBrightnessUseCase(lightRepository: _lightRepository)
        _updateLightColorUseCase = UpdateLightColorUseCase(lightRepository: _lightRepository)
        _addLightToEnvironmentUseCase = AddLightToEnvironmentUseCase(lightRepository: _lightRepository)
        _getEnvironmentLightsUseCase = GetEnvironmentLightsUseCase(lightRepository: _lightRepository)
        _createRoomWithLightsUseCase = CreateRoomWithLightsUseCase(roomRepository: roomRepository, lightRepository: _lightRepository)
    }
    
    /// Настройка реального RoomRepository с зависимостями
    /// - Parameter dataPersistenceService: Сервис для работы с SwiftData
    func configureRoomRepository(dataPersistenceService: DataPersistenceService) {
        _roomRepositoryFactory = {
            RoomRepositoryImpl(modelContext: dataPersistenceService.container.mainContext)
        }
        
        // Принудительно пересоздаем зависимые Use Cases
        _roomRepository = _roomRepositoryFactory!()
        _createRoomWithLightsUseCase = CreateRoomWithLightsUseCase(roomRepository: _roomRepository, lightRepository: lightRepository)
        _getRoomsUseCase = GetRoomsUseCase(roomRepository: _roomRepository)
        _deleteRoomUseCase = DeleteRoomUseCase(roomRepository: _roomRepository)
        _moveLightBetweenRoomsUseCase = MoveLightBetweenRoomsUseCase(roomRepository: _roomRepository, lightRepository: lightRepository)
        _removeLightFromRoomUseCase = RemoveLightFromRoomUseCase(roomRepository: _roomRepository)
    }
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
        // ✅ ИСПРАВЛЕНО: Ищем лампу среди всех доступных ламп
        return getAllLights()
            .map { lights in
                lights.first { $0.id == id }
            }
            .eraseToAnyPublisher()
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
        // ✅ ИСПРАВЛЕНО: Возвращаем сохраненные комнаты
        return roomsSubject
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRoom(by id: String) -> AnyPublisher<RoomEntity?, Error> {
        return roomsSubject
            .map { rooms in
                rooms.first { $0.id == id }
            }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRoomsByType(_ type: RoomType) -> AnyPublisher<[RoomEntity], Error> {
        return roomsSubject
            .map { rooms in
                rooms.filter { $0.type.parentEnvironmentType == type }
            }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getActiveRooms() -> AnyPublisher<[RoomEntity], Error> {
        return roomsSubject
            .map { rooms in
                rooms.filter { $0.isActive }
            }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func createRoom(_ room: RoomEntity) -> AnyPublisher<Void, Error> {
        // ✅ ИСПРАВЛЕНО: Сохраняем комнату в памяти
        var currentRooms = roomsSubject.value
        currentRooms.append(room)
        roomsSubject.send(currentRooms)
        
        print("✅ MockRoomRepository: Комната '\(room.name)' сохранена. Всего комнат: \(currentRooms.count)")
        
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func updateRoom(_ room: RoomEntity) -> AnyPublisher<Void, Error> {
        // ✅ ИСПРАВЛЕНО: Обновляем комнату в памяти
        var currentRooms = roomsSubject.value
        if let index = currentRooms.firstIndex(where: { $0.id == room.id }) {
            currentRooms[index] = room
            roomsSubject.send(currentRooms)
            print("✅ MockRoomRepository: Комната '\(room.name)' обновлена")
        }
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func deleteRoom(id: String) -> AnyPublisher<Void, Error> {
        // ✅ ИСПРАВЛЕНО: Удаляем комнату из памяти
        var currentRooms = roomsSubject.value
        currentRooms.removeAll { $0.id == id }
        roomsSubject.send(currentRooms)
        print("✅ MockRoomRepository: Комната удалена. Осталось комнат: \(currentRooms.count)")
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func addLightToRoom(roomId: String, lightId: String) -> AnyPublisher<Void, Error> {
        // ✅ ИСПРАВЛЕНО: Реально добавляем лампу в комнату
        var currentRooms = roomsSubject.value
        if let index = currentRooms.firstIndex(where: { $0.id == roomId }) {
            var updatedRoom = currentRooms[index]
            if !updatedRoom.lightIds.contains(lightId) {
                updatedRoom.lightIds.append(lightId)
                updatedRoom.updatedAt = Date()
                currentRooms[index] = updatedRoom
                roomsSubject.send(currentRooms)
                print("✅ MockRoomRepository: Лампа \(lightId) добавлена в комнату '\(updatedRoom.name)'")
            }
        }
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func removeLightFromRoom(roomId: String, lightId: String) -> AnyPublisher<Void, Error> {
        // ✅ ИСПРАВЛЕНО: Реально удаляем лампу из комнаты
        var currentRooms = roomsSubject.value
        if let index = currentRooms.firstIndex(where: { $0.id == roomId }) {
            var updatedRoom = currentRooms[index]
            if let lightIndex = updatedRoom.lightIds.firstIndex(of: lightId) {
                updatedRoom.lightIds.remove(at: lightIndex)
                updatedRoom.updatedAt = Date()
                currentRooms[index] = updatedRoom
                roomsSubject.send(currentRooms)
                print("✅ MockRoomRepository: Лампа \(lightId) удалена из комнаты '\(updatedRoom.name)'")
            }
        }
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
