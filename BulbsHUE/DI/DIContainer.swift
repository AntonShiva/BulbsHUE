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
    
    // MARK: - Environment Scenes
    private lazy var _environmentScenesRepository: EnvironmentScenesRepositoryProtocol = {
        let localDataSource = EnvironmentScenesLocalDataSource()
        return EnvironmentScenesRepositoryImpl(localDataSource: localDataSource)
    }()
    
    private lazy var _environmentScenesUseCase: EnvironmentScenesUseCaseProtocol = {
        return EnvironmentScenesUseCase(repository: _environmentScenesRepository)
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
    
    private lazy var _updateLightTypeUseCase: UpdateLightTypeUseCase = {
        return UpdateLightTypeUseCase(dataPersistenceService: _dataPersistenceService)
    }()
    
    private lazy var _updateRoomUseCase: UpdateRoomUseCase = {
        return UpdateRoomUseCase(roomRepository: roomRepository)
    }()
    
    private lazy var _updateLightNameUseCase: UpdateLightNameUseCase = {
        // По умолчанию используем заглушку, будет переинициализирован в configureLightRepository
        let dummyClient = HueAPIClient(bridgeIP: "")
        return UpdateLightNameUseCase(
            dataPersistenceService: _dataPersistenceService, 
            hueAPIClient: dummyClient
        )
    }()
    
    private lazy var _updateRoomNameUseCase: UpdateRoomNameUseCase = {
        return UpdateRoomNameUseCase(roomRepository: roomRepository)
    }()
    
    private lazy var _deleteLightUseCase: DeleteLightUseCase = {
        return DeleteLightUseCase(lightRepository: lightRepository, dataPersistenceService: _dataPersistenceService)
    }()
    
    /// DataPersistenceService для Use Cases
    private var _dataPersistenceService: DataPersistenceService = DataPersistenceService()
    
    // MARK: - Services
    // УДАЛЕНО: AppStore больше не нужен после миграции на @Observable
    // private lazy var _appStore: AppStore = { ... }
    
    private lazy var _lightColorStateService: LightColorStateService = {
        let service = LightColorStateService.shared
        MemoryLeakDiagnosticsService.registerService(service, name: "LightColorStateService")
        return service
    }()
    
    private lazy var _lightingColorService: LightingColorService = {
        let service = LightingColorService(lightControlService: nil, appViewModel: nil)
        MemoryLeakDiagnosticsService.registerService(service, name: "LightingColorService")
        return service
    }()
    
    private lazy var _presetColorService: PresetColorService = {
        let service = PresetColorService(
            lightingColorService: _lightingColorService,
            lightColorStateService: _lightColorStateService,
            appViewModel: nil
        )
        MemoryLeakDiagnosticsService.registerService(service, name: "PresetColorService")
        return service
    }()
    
    private var _presetColorServiceFactory: (() -> PresetColorService)?
    
    // MARK: - Room Control Color Service
    
    private lazy var _roomControlColorService: RoomControlColorService = {
        let service = RoomControlColorService()
        MemoryLeakDiagnosticsService.registerService(service, name: "RoomControlColorService")
        return service
    }()
    
    private lazy var _roomColorStateService: RoomColorStateService = {
        let service = RoomColorStateService.shared
        MemoryLeakDiagnosticsService.registerService(service, name: "RoomColorStateService")
        return service
    }()
    
    // MARK: - Navigation
    private lazy var _navigationManager: NavigationManager = {
        let manager = NavigationManager.shared
        MemoryLeakDiagnosticsService.registerService(manager, name: "NavigationManager")
        return manager
    }()
    
    private init() {}
    
    // MARK: - Public Access
    
    // Repositories
    var lightRepository: LightRepositoryProtocol { _lightRepository }
    var roomRepository: RoomRepositoryProtocol { _roomRepository }
    var bridgeRepository: BridgeRepositoryProtocol { _bridgeRepository }
    var persistenceRepository: PersistenceRepositoryProtocol { _persistenceRepository }
    var environmentScenesRepository: EnvironmentScenesRepositoryProtocol { _environmentScenesRepository }
    
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
    var updateLightTypeUseCase: UpdateLightTypeUseCase { _updateLightTypeUseCase }
    var updateRoomUseCase: UpdateRoomUseCase { _updateRoomUseCase }
    var updateLightNameUseCase: UpdateLightNameUseCase { _updateLightNameUseCase }
    var updateRoomNameUseCase: UpdateRoomNameUseCase { _updateRoomNameUseCase }
    var deleteLightUseCase: DeleteLightUseCase { _deleteLightUseCase }
    var environmentScenesUseCase: EnvironmentScenesUseCaseProtocol { _environmentScenesUseCase }
    
    // Services
    // УДАЛЕНО: appStore больше не нужен после миграции на @Observable
    // var appStore: AppStore { _appStore }
    var navigationManager: NavigationManager { _navigationManager }
    var lightColorStateService: LightColorStateService { _lightColorStateService }
    var lightingColorService: LightingColorService { _lightingColorService }
    var presetColorService: PresetColorService { 
        _presetColorServiceFactory?() ?? _presetColorService 
    }
    var roomControlColorService: RoomControlColorService { _roomControlColorService }
    var roomColorStateService: RoomColorStateService { _roomColorStateService }
    
    // MARK: - Configuration
    
    /// Настройка реального LightRepository с зависимостями
    /// - Parameters:
    ///   - appViewModel: AppViewModel с данными Philips Hue API
    ///   - dataPersistenceService: Сервис для работы с локальными данными
    func configureLightRepository(appViewModel: AppViewModel, dataPersistenceService: DataPersistenceService) {
        // ✅ ИСПРАВЛЕНО: Правильная очистка старых сервисов перед пересозданием
        cleanupOldLightServices()
        
        _lightRepositoryFactory = {
            PhilipsHueLightRepository(
                appViewModel: appViewModel,
                dataPersistenceService: dataPersistenceService
            )
        }
        
        // Обновляем DataPersistenceService для Use Cases
        _dataPersistenceService = dataPersistenceService
        
        // Создаем LightControlService с AppViewModel
        let lightControlService = LightControlService(appViewModel: appViewModel)
        
        // Пересоздаем LightingColorService с правильными зависимостями
        _lightingColorService = LightingColorService(
            lightControlService: lightControlService,
            appViewModel: appViewModel
        )
        
        // Настраиваем PresetColorService с AppViewModel и обновленным LightingColorService
        _presetColorServiceFactory = {
            PresetColorService(
                lightingColorService: self._lightingColorService,
                lightColorStateService: self._lightColorStateService,
                appViewModel: appViewModel
            )
        }
        
        // ✅ ИСПРАВЛЕНО: Безопасное пересоздание с проверкой
        if let factory = _presetColorServiceFactory {
            _presetColorService = factory()
        }
        
        // ✅ ИСПРАВЛЕНО: Безопасное пересоздание репозитория и Use Cases
        if let lightRepoFactory = _lightRepositoryFactory {
            _lightRepository = lightRepoFactory()
            
            // ✅ ДОБАВЛЕНО: Регистрируем репозиторий в диагностике памяти
            // Временно отключено из-за проблемы с протокольным типом
            // MemoryLeakDiagnosticsService.registerRepository(_lightRepository, name: "PhilipsHueLightRepository")
            
            recreateLightUseCases(with: _lightRepository, appViewModel: appViewModel)
        }
    }
    
    // MARK: - Private Cleanup Methods
    
    /// Очистка старых сервисов связанных с лампами перед пересозданием
    private func cleanupOldLightServices() {
        print("🧹 DIContainer: Очистка старых сервисов перед пересозданием")
        
        // Обнуляем фабрики для принудительного пересоздания
        _presetColorServiceFactory = nil
        _lightRepositoryFactory = nil
        
        print("✅ DIContainer: Старые сервисы очищены")
    }
    
    /// Пересоздание Use Cases связанных с лампами
    private func recreateLightUseCases(with lightRepository: LightRepositoryProtocol, appViewModel: AppViewModel) {
        print("🔄 DIContainer: Пересоздание Light Use Cases")
        
        _toggleLightUseCase = ToggleLightUseCase(lightRepository: lightRepository)
        _updateLightBrightnessUseCase = UpdateLightBrightnessUseCase(lightRepository: lightRepository)
        _updateLightColorUseCase = UpdateLightColorUseCase(lightRepository: lightRepository)
        _addLightToEnvironmentUseCase = AddLightToEnvironmentUseCase(lightRepository: lightRepository)
        _getEnvironmentLightsUseCase = GetEnvironmentLightsUseCase(lightRepository: lightRepository)
        _createRoomWithLightsUseCase = CreateRoomWithLightsUseCase(roomRepository: roomRepository, lightRepository: lightRepository)
        _updateLightTypeUseCase = UpdateLightTypeUseCase(dataPersistenceService: _dataPersistenceService)
        _updateLightNameUseCase = UpdateLightNameUseCase(
            dataPersistenceService: _dataPersistenceService,
            hueAPIClient: appViewModel.apiClient
        )
        _deleteLightUseCase = DeleteLightUseCase(lightRepository: lightRepository, dataPersistenceService: _dataPersistenceService)
        
        print("✅ DIContainer: Light Use Cases пересозданы")
    }
    
    /// Настройка реального RoomRepository с зависимостями
    /// - Parameter dataPersistenceService: Сервис для работы с SwiftData
    func configureRoomRepository(dataPersistenceService: DataPersistenceService) {
        // ✅ ИСПРАВЛЕНО: Правильная очистка старых сервисов перед пересозданием
        cleanupOldRoomServices()
        
        _roomRepositoryFactory = {
            RoomRepositoryImpl(modelContext: dataPersistenceService.container.mainContext)
        }
        
        // ✅ ИСПРАВЛЕНО: Безопасное пересоздание репозитория и Use Cases
        if let roomRepoFactory = _roomRepositoryFactory {
            _roomRepository = roomRepoFactory()
            
            // ✅ ДОБАВЛЕНО: Регистрируем репозиторий в диагностике памяти
            // Временно отключено из-за проблемы с протокольным типом
            // MemoryLeakDiagnosticsService.registerRepository(_roomRepository, name: "RoomRepositoryImpl")
            
            recreateRoomUseCases(with: _roomRepository)
        }
    }
    
    /// Очистка старых сервисов связанных с комнатами перед пересозданием
    private func cleanupOldRoomServices() {
        print("🧹 DIContainer: Очистка старых Room сервисов перед пересозданием")
        
        // Обнуляем фабрики для принудительного пересоздания
        _roomRepositoryFactory = nil
        
        print("✅ DIContainer: Старые Room сервисы очищены")
    }
    
    /// Пересоздание Use Cases связанных с комнатами
    private func recreateRoomUseCases(with roomRepository: RoomRepositoryProtocol) {
        print("🔄 DIContainer: Пересоздание Room Use Cases")
        
        _createRoomWithLightsUseCase = CreateRoomWithLightsUseCase(roomRepository: roomRepository, lightRepository: lightRepository)
        _getRoomsUseCase = GetRoomsUseCase(roomRepository: roomRepository)
        _deleteRoomUseCase = DeleteRoomUseCase(roomRepository: roomRepository)
        _moveLightBetweenRoomsUseCase = MoveLightBetweenRoomsUseCase(roomRepository: roomRepository, lightRepository: lightRepository)
        _removeLightFromRoomUseCase = RemoveLightFromRoomUseCase(roomRepository: roomRepository)
        _updateRoomUseCase = UpdateRoomUseCase(roomRepository: roomRepository)
        _updateRoomNameUseCase = UpdateRoomNameUseCase(roomRepository: roomRepository)
        
        print("✅ DIContainer: Room Use Cases пересозданы")
    }
}

// MARK: - УДАЛЕНО: Logging Middleware (больше не нужен без Redux)
// struct LoggingMiddleware: Middleware {
//    func process(action: AppAction, state: AppState, store: AppStore) -> AppAction {
//        return action
//    }
// }

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
