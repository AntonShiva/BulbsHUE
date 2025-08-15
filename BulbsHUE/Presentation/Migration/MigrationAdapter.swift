//
//  MigrationAdapter.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

/// Feature flags для управления миграцией
struct MigrationFeatureFlags {
    /// Использовать новую архитектуру для Bridge
    static let useNewBridgeArchitecture = true // ✅ АКТИВИРУЕМ Bridge Service
    
    /// Использовать Redux для ламп
    static let useReduxForLights = false
    
    /// Использовать Redux для сцен
    static let useReduxForScenes = false
    
    /// Использовать Redux для групп
    static let useReduxForGroups = false
    
    /// Режим отладки миграции
    static let debugMigration = true
}

/// Адаптер для безопасной миграции между старой и новой архитектурой
class MigrationAdapter: ObservableObject {
    
    // MARK: - Dependencies
    private let store: AppStore
    private let appViewModel: AppViewModel
    
    // New Bridge Architecture Dependencies
    private let bridgeRepository: BridgeRepository?
    private let discoverBridgesUseCase: DiscoverBridgesUseCase?
    private let connectToBridgeUseCase: ConnectToBridgeUseCase?
    private let getSavedBridgeUseCase: GetSavedBridgeUseCase?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(store: AppStore, appViewModel: AppViewModel) {
        self.store = store
        self.appViewModel = appViewModel
        
        // Инициализируем новую Bridge архитектуру если флаг активен
        if MigrationFeatureFlags.useNewBridgeArchitecture {
            // Создаем HueAPIClient с dummy IP (будет переопределен при подключении)
            let hueAPIClient = HueAPIClient(bridgeIP: "192.168.1.1") // Временный IP
            let bridgeRepo = BridgeRepositoryImpl(hueAPIClient: hueAPIClient)
            
            self.bridgeRepository = bridgeRepo
            self.discoverBridgesUseCase = DiscoverBridgesUseCase(bridgeRepository: bridgeRepo)
            self.connectToBridgeUseCase = ConnectToBridgeUseCase(bridgeRepository: bridgeRepo)
            self.getSavedBridgeUseCase = GetSavedBridgeUseCase(bridgeRepository: bridgeRepo)
        } else {
            self.bridgeRepository = nil
            self.discoverBridgesUseCase = nil
            self.connectToBridgeUseCase = nil
            self.getSavedBridgeUseCase = nil
        }
        
        if MigrationFeatureFlags.debugMigration {
            print("🔄 MigrationAdapter инициализирован")
            print("   Bridge Architecture: \(MigrationFeatureFlags.useNewBridgeArchitecture ? "✅ NEW" : "❌ OLD")")
            print("   Redux Lights: \(MigrationFeatureFlags.useReduxForLights ? "✅ ENABLED" : "❌ DISABLED")")
        }
        
        // Загружаем сохраненный мост при инициализации
        loadSavedBridgeIfNeeded()
    }
    
    // MARK: - Bridge Migration
    
    /// Получить текущий мост (с поддержкой миграции)
    var currentBridge: Bridge? {
        if MigrationFeatureFlags.useNewBridgeArchitecture {
            // Используем новую архитектуру (Redux)
            return store.state.bridge.currentBridge?.toLegacy()
        } else {
            // Используем старую архитектуру
            return appViewModel.currentBridge
        }
    }
    
    /// Получить статус подключения (с поддержкой миграции)
    var connectionStatus: ConnectionStatus {
        if MigrationFeatureFlags.useNewBridgeArchitecture {
            // Маппим новый статус на старый
            return store.state.bridge.connectionStatus
        } else {
            return appViewModel.connectionStatus
        }
    }
    
    /// Подключиться к мосту (dual write во время миграции)
    func connectToBridge(_ bridge: Bridge) {
        if MigrationFeatureFlags.debugMigration {
            print("🔗 Подключение к мосту: \(bridge.name ?? "Unknown")")
        }
        
        if MigrationFeatureFlags.useNewBridgeArchitecture {
            // Используем новую архитектуру
            let bridgeEntity = bridge.toDomain()
            connectToBridgeUseCase?.execute(bridge: bridgeEntity)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ Ошибка подключения к мосту (новая архитектура): \(error)")
                        }
                    },
                    receiveValue: { [weak self] connectedBridge in
                        print("✅ Мост подключен через новую архитектуру: \(connectedBridge.name)")
                        
                        // Обновляем Redux состояние
                        self?.store.dispatch(.bridge(.bridgeConnected(connectedBridge, applicationKey: connectedBridge.applicationKey ?? "")))
                        self?.store.dispatch(.bridge(.setConnectionStatus(.connected)))
                        
                        // Dual write: обновляем и старое состояние для совместимости
                        if let legacyBridge = connectedBridge.toLegacy() {
                            self?.appViewModel.currentBridge = legacyBridge
                            self?.appViewModel.connectionStatus = .connected
                        }
                    }
                )
                .store(in: &cancellables)
        } else {
            // Используем старую архитектуру
            appViewModel.connectToBridge(bridge)
        }
    }
    
    /// Поиск мостов (с поддержкой новой архитектуры)
    func discoverBridges(completion: @escaping ([Bridge]) -> Void) {
        if MigrationFeatureFlags.debugMigration {
            print("🔍 Запуск поиска мостов")
        }
        
        if MigrationFeatureFlags.useNewBridgeArchitecture {
            // Используем новую архитектуру
            discoverBridgesUseCase?.execute()
                .sink(
                    receiveCompletion: { complete in
                        if case .failure(let error) = complete {
                            print("❌ Ошибка поиска мостов (новая архитектура): \(error)")
                            completion([])
                        }
                    },
                    receiveValue: { bridgeEntities in
                        let legacyBridges = bridgeEntities.compactMap { $0.toLegacy() }
                        print("✅ Найдено мостов через новую архитектуру: \(legacyBridges.count)")
                        completion(legacyBridges)
                    }
                )
                .store(in: &cancellables)
        } else {
            // Используем старую архитектуру
            // TODO: Использовать старый метод поиска мостов
            completion([])
        }
    }
    
    /// Загрузка сохраненного моста при инициализации
    private func loadSavedBridgeIfNeeded() {
        guard MigrationFeatureFlags.useNewBridgeArchitecture else { return }
        
        getSavedBridgeUseCase?.execute()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Ошибка загрузки сохраненного моста: \(error)")
                    }
                },
                receiveValue: { [weak self] savedBridge in
                    if let bridge = savedBridge {
                        print("� Загружен сохраненный мост: \(bridge.name)")
                        
                        // Обновляем Redux состояние
                        self?.store.dispatch(.bridge(.bridgeConnected(bridge, applicationKey: bridge.applicationKey ?? "")))
                        self?.store.dispatch(.bridge(.setConnectionStatus(bridge.isConnected ? .connected : .disconnected)))
                        
                        // Dual write: обновляем и старое состояние для совместимости
                        if let legacyBridge = bridge.toLegacy() {
                            self?.appViewModel.currentBridge = legacyBridge
                            self?.appViewModel.connectionStatus = bridge.isConnected ? .connected : .disconnected
                        }
                    } else {
                        print("ℹ️ Нет сохраненного моста")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Lights Migration
    
    /// Получить лампы (с поддержкой миграции)
    var lights: [Light] {
        if MigrationFeatureFlags.useReduxForLights {
            // Используем Redux
            return store.state.lights.assignedLights.map { $0.toLegacy() }
        } else {
            // Используем старую систему
            return appViewModel.lightsViewModel.lights
        }
    }
    
    /// Publisher для ламп (с поддержкой миграции)
    var lightsPublisher: AnyPublisher<[Light], Never> {
        if MigrationFeatureFlags.useReduxForLights {
            return store.$state
                .map { $0.lights.assignedLights.map { $0.toLegacy() } }
                .eraseToAnyPublisher()
        } else {
            return appViewModel.lightsViewModel.$lights
                .eraseToAnyPublisher()
        }
    }
    
    /// Обновить лампу (dual write во время миграции)
    func updateLight(_ light: Light) {
        if MigrationFeatureFlags.debugMigration {
            print("💡 Обновление лампы: \(light.metadata.name)")
        }
        
        // Всегда пишем в старую систему для совместимости
        // TODO: Найти правильный метод для обновления лампы в старой системе
        // appViewModel.lightsViewModel.updateLight(light)
        
        // Если включена новая система - пишем и туда
        if MigrationFeatureFlags.useReduxForLights {
            store.dispatch(.light(.lightUpdated(light.toDomain())))
        }
    }
    
    // MARK: - Scenes Migration
    
    var scenes: [HueScene] {
        if MigrationFeatureFlags.useReduxForScenes {
            return store.state.scenes.scenes.map { $0.toLegacy() }
        } else {
            return appViewModel.scenesViewModel.scenes
        }
    }
    
    // MARK: - Groups Migration
    
    var groups: [HueGroup] {
        if MigrationFeatureFlags.useReduxForGroups {
            return store.state.groups.groups.map { $0.toLegacy() }
        } else {
            return appViewModel.groupsViewModel.groups
        }
    }
}

// MARK: - Extensions для конвертации между моделями

extension BridgeEntity {
    /// Конвертировать новую модель в старую
    func toLegacy() -> Bridge? {
        return Bridge(
            id: self.id,
            internalipaddress: self.ipAddress,
            port: 443,
            macaddress: nil, // TODO: Добавить MAC address если есть
            name: self.name
        )
    }
}

extension Bridge {
    /// Конвертировать старую модель в новую
    func toDomain() -> BridgeEntity {
        return BridgeEntity(from: self)
    }
}

extension LightEntity {
    /// Конвертировать новую модель в старую
    func toLegacy() -> Light {
        // TODO: Полная реализация конвертации LightEntity -> Light
        // Пока возвращаем минимальную заглушку для компиляции
        var light = Light()
        light.id = self.id
        light.metadata.name = self.name
        light.on.on = self.isOn
        
        if let brightness = self.brightness as Double? {
            light.dimming = Dimming(brightness: brightness)
        }
        
        return light
    }
}

extension Light {
    /// Конвертировать старую модель в новую
    func toDomain() -> LightEntity {
        return LightEntity(
            id: self.id,
            name: self.metadata.name,
            type: .other, // TODO: Добавить mapping для типов
            subtype: nil, // TODO: Добавить mapping для подтипов
            isOn: self.on.on,
            brightness: self.dimming?.brightness ?? 0.0,
            color: nil, // TODO: Добавить mapping для цвета
            colorTemperature: self.color_temperature?.mirek,
            isReachable: true, // TODO: Добавить реальное значение
            roomId: nil, // TODO: Добавить mapping для комнат
            userSubtype: self.metadata.userSubtypeName,
            userIcon: self.metadata.userSubtypeIcon
        )
    }
}

extension SceneEntity {
    /// Конвертировать новую модель в старую
    func toLegacy() -> HueScene {
        // TODO: Полная реализация конвертации SceneEntity -> HueScene
        var scene = HueScene()
        scene.id = self.id
        scene.metadata.name = self.name
        return scene
    }
}

extension GroupEntity {
    /// Конвертировать новую модель в старую
    func toLegacy() -> HueGroup {
        // TODO: Полная реализация конвертации GroupEntity -> HueGroup
        var group = HueGroup()
        group.id = self.id
        if group.metadata == nil {
            group.metadata = GroupMetadata()
        }
        group.metadata?.name = self.name
        return group
    }
}
