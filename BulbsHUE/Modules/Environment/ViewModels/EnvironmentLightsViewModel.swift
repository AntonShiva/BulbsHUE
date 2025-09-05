//
//  EnvironmentLightsViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel для управления лампами в Environment
/// Следует принципам MVVM и SOLID - Single Responsibility Principle
@MainActor
final class EnvironmentLightsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Список ламп с назначенными комнатами (из персистентного хранилища + API)
    @Published var assignedLights: [Light] = []
    
    /// Статус загрузки данных
    @Published var isLoading: Bool = false
    
    /// Ошибка загрузки (если есть)
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    /// Ссылка на основной AppViewModel для доступа к API данным
    private weak var appViewModel: AppViewModel?
    
    /// Сервис для персистентного хранения
    private weak var dataPersistenceService: DataPersistenceService?
    
    /// Подписки Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Инициализация с внедрением зависимостей
    /// - Parameters:
    ///   - appViewModel: Основной ViewModel приложения
    ///   - dataPersistenceService: Сервис персистентных данных
    init(appViewModel: AppViewModel, dataPersistenceService: DataPersistenceService) {
        self.appViewModel = appViewModel
        self.dataPersistenceService = dataPersistenceService
        setupObservers()
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    /// Принудительно обновить список ламп
    func refreshLights() {
        appViewModel?.lightsViewModel.loadLights()
    }
    
    /// Принудительная синхронизация состояния без запроса к API
    func forceStateSync() {
        guard let appViewModel = appViewModel else { return }
        handleAPILightsUpdate(appViewModel.lightsViewModel.lights)
    }
    
    /// Назначить лампу к Environment
    /// - Parameter light: Лампа для назначения
    func assignLightToEnvironment(_ light: Light) {
        // Просто вызываем сервис - UI обновится автоматически через Publisher
        dataPersistenceService?.assignLightToEnvironment(light.id)
    }
    
    /// Убрать лампу из Environment
    /// - Parameter lightId: ID лампы для удаления
    func removeLightFromEnvironment(_ lightId: String) {
        // Просто вызываем сервис - UI обновится автоматически через Publisher
        dataPersistenceService?.removeLightFromEnvironment(lightId)
    }
    
    // MARK: - Computed Properties
    
    /// Получить количество назначенных ламп
    var assignedLightsCount: Int {
        assignedLights.count
    }
    
    /// Проверить, есть ли назначенные лампы
    var hasAssignedLights: Bool {
        !assignedLights.isEmpty
    }
    
    /// Лампы без назначенной комнаты
    var unassignedLights: [Light] {
        assignedLights.filter { light in
            // TODO: Добавить проверку назначения комнаты
            return true
        }
    }
    
    /// Лампы с назначенными комнатами
    var roomAssignedLights: [Light] {
        assignedLights.filter { light in
            // TODO: Добавить проверку назначения комнаты
            return false
        }
    }
    
    // MARK: - Private Methods
    
    /// Настройка наблюдателей для автоматического обновления данных
    private func setupObservers() {
        guard let appViewModel = appViewModel,
              let dataPersistenceService = dataPersistenceService else { return }
        
        // ГЛАВНЫЙ FIX: Подписываемся на изменения в DataPersistenceService
        dataPersistenceService.$assignedLights
            .receive(on: RunLoop.main)
            .sink { [weak self] persistenceLights in
                // ✅ ОБЪЕДИНЯЕМ данные из БД с актуальным состоянием из API
                guard let self = self, let appViewModel = self.appViewModel else { return }
                
                let apiLights = appViewModel.lightsViewModel.lights
                let hybridLights = persistenceLights.map { persistentLight in
                    // Ищем актуальное состояние лампы в API
                    if let apiLight = apiLights.first(where: { $0.id == persistentLight.id }) {
                        // Объединяем: состояние из API + пользовательские поля из БД
                        var hybridLight = apiLight
                        hybridLight.metadata.userSubtypeName = persistentLight.metadata.userSubtypeName
                        hybridLight.metadata.userSubtypeIcon = persistentLight.metadata.userSubtypeIcon
                        return hybridLight
                    } else {
                        // API состояние недоступно, используем данные из БД
                        return persistentLight
                    }
                }
                
                self.assignedLights = hybridLights
            }
            .store(in: &cancellables)
        
        // Подписываемся на изменения списка ламп из API
        appViewModel.lightsViewModel.$lights
            .receive(on: RunLoop.main)
            .sink { [weak self] apiLights in
                self?.handleAPILightsUpdate(apiLights)
            }
            .store(in: &cancellables)
        
        // Подписываемся на состояние загрузки
        appViewModel.lightsViewModel.$isLoading
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
    }
    
    /// Обработка обновления ламп из API
    /// - Parameter apiLights: Лампы из API
    private func handleAPILightsUpdate(_ apiLights: [Light]) {
        // Синхронизируем с локальным хранилищем
        dataPersistenceService?.syncWithAPILights(apiLights)
        
        // UI обновится автоматически через Publisher в DataPersistenceService
    }
    
    /// Загрузить начальные данные
    private func loadInitialData() {
        // Данные уже загружаются автоматически через Publisher в setupObservers()
        // Запускаем обновление из API если нужно
        guard let appViewModel = appViewModel else { return }
        
        if appViewModel.lightsViewModel.lights.isEmpty {
            // Если API данных нет, инициируем загрузку
            refreshLights()
        }
    }
}

// MARK: - Mock для тестирования

extension EnvironmentLightsViewModel {
    /// Создать mock ViewModel для превью
    static func createMock() -> EnvironmentLightsViewModel {
        let mockAppViewModel = AppViewModel(dataPersistenceService: nil)
        let mockDataService = DataPersistenceService.createMock()
        return EnvironmentLightsViewModel(
            appViewModel: mockAppViewModel, 
            dataPersistenceService: mockDataService
        )
    }
}
