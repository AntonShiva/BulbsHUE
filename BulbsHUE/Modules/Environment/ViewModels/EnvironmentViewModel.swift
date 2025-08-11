//
//  EnvironmentViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/11/25.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel для управления экраном Environment
/// Следует принципам MVVM и обеспечивает правильную абстракцию данных
/// Интегрирован с SwiftData для персистентного хранения
@MainActor
class EnvironmentViewModel: ObservableObject {
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
        isLoading = true
        error = nil
        
        // Загружаем из API
        appViewModel?.lightsViewModel.loadLights()
        
        // Также обновляем из локального хранилища
        loadAssignedLightsFromStorage()
    }
    
    /// Назначить лампу в Environment (сделать видимой)
    /// - Parameter light: Лампа для назначения
    func assignLightToEnvironment(_ light: Light) {
        dataPersistenceService?.assignLightToEnvironment(light.id)
        loadAssignedLightsFromStorage()
    }
    
    /// Убрать лампу из Environment
    /// - Parameter lightId: ID лампы для удаления
    func removeLightFromEnvironment(_ lightId: String) {
        dataPersistenceService?.removeLightFromEnvironment(lightId)
        loadAssignedLightsFromStorage()
    }
    
    /// Получить количество назначенных ламп
    var assignedLightsCount: Int {
        assignedLights.count
    }
    
    /// Проверить, есть ли назначенные лампы
    var hasAssignedLights: Bool {
        !assignedLights.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// Настройка наблюдателей для автоматического обновления данных
    private func setupObservers() {
        guard let appViewModel = appViewModel else { return }
        
        // Подписываемся на изменения списка ламп из API
        appViewModel.lightsViewModel.$lights
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apiLights in
                self?.handleAPILightsUpdate(apiLights)
            }
            .store(in: &cancellables)
        
        // Подписываемся на состояние загрузки
        appViewModel.lightsViewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if !isLoading {
                    // Когда загрузка завершена, обновляем локальные данные
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)
        
        // Подписываемся на ошибки
        appViewModel.lightsViewModel.$error
            .receive(on: DispatchQueue.main)
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
    }
    
    /// Обработка обновления ламп из API
    /// - Parameter apiLights: Лампы из API
    private func handleAPILightsUpdate(_ apiLights: [Light]) {
        // Синхронизируем с локальным хранилищем
        dataPersistenceService?.syncWithAPILights(apiLights)
        
        // Обновляем отображаемый список
        loadAssignedLightsFromStorage()
    }
    
    /// Загрузить назначенные лампы из персистентного хранилища
    private func loadAssignedLightsFromStorage() {
        guard let dataPersistenceService = dataPersistenceService else { return }
        
        // Получаем назначенные лампы из хранилища
        let storedLights = dataPersistenceService.fetchAssignedLights()
        
        // Фильтруем только активные лампы (подключенные к сети)
        assignedLights = storedLights.filter { light in
            // Лампа считается активной если она включена или имеет яркость > 0
            return light.on.on || (light.dimming?.brightness ?? 0) > 0
        }
        
        // Сортируем по имени для стабильного отображения
        assignedLights.sort { $0.metadata.name < $1.metadata.name }
        
        print("✅ Загружено \(assignedLights.count) назначенных ламп из хранилища")
    }
    
    /// Загрузить начальные данные
    private func loadInitialData() {
        // Сначала загружаем из локального хранилища для быстрого отображения
        loadAssignedLightsFromStorage()
        
        // Затем обновляем из API если доступно
        guard let appViewModel = appViewModel else { return }
        
        if !appViewModel.lightsViewModel.lights.isEmpty {
            handleAPILightsUpdate(appViewModel.lightsViewModel.lights)
        } else {
            // Если API данных нет, инициируем загрузку
            refreshLights()
        }
    }
}

// MARK: - Extensions

extension EnvironmentViewModel {
    /// Создать mock ViewModel для превью
    static func createMock() -> EnvironmentViewModel {
        let mockAppViewModel = AppViewModel()
        let mockDataService = DataPersistenceService.createMock()
        return EnvironmentViewModel(
            appViewModel: mockAppViewModel, 
            dataPersistenceService: mockDataService
        )
    }
}
