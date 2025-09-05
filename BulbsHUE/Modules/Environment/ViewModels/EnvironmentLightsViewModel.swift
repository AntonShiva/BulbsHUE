//
//  EnvironmentLightsViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import Foundation
import Combine
import Observation
import SwiftUI

/// ViewModel для управления лампами в Environment
/// Следует принципам MVVM и SOLID - Single Responsibility Principle
@MainActor
@Observable
class EnvironmentLightsViewModel  {
    // MARK: - Published Properties
    
    /// Список ламп с назначенными комнатами (из персистентного хранилища + API)
    var assignedLights: [Light] = []
    
    /// Статус загрузки данных
    var isLoading: Bool = false
    
    /// Ошибка загрузки (если есть)
    var error: Error?
    
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
        syncWithPersistenceService()
    }
    
    /// Обновить список назначенных ламп из DataPersistenceService
    func refreshAssignedLights() {
        syncWithPersistenceService()
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
        
        // ГЛАВНЫЙ FIX: @Observable не поддерживает publishers, используем ручную синхронизацию
        // dataPersistenceService.$assignedLights - больше не доступно в @Observable
        // Вызываем начальную синхронизацию данных
        loadInitialData()
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
        // Синхронизируем с данными из DataPersistenceService
        syncWithPersistenceService()
        
        // Запускаем обновление из API если нужно
        guard let appViewModel = appViewModel else { return }
        
        if appViewModel.lightsViewModel.lights.isEmpty {
            // Если API данных нет, инициируем загрузку
            Task {
                await appViewModel.lightsViewModel.refreshLightsWithStatus()
            }
        }
    }
    
    /// Синхронизировать с DataPersistenceService
    private func syncWithPersistenceService() {
        guard let dataPersistenceService = dataPersistenceService else { return }
        assignedLights = dataPersistenceService.assignedLights
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
