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
        
        // DataPersistenceService автоматически обновит UI через Publisher
    }
    
    /// Назначить лампу в Environment (сделать видимой)
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
        guard let appViewModel = appViewModel,
              let dataPersistenceService = dataPersistenceService else { return }
        
        // ГЛАВНЫЙ FIX: Подписываемся на изменения в DataPersistenceService
        dataPersistenceService.$assignedLights
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedLights in
                print("🔄 EnvironmentViewModel получил обновление: \(updatedLights.count) ламп")
                print("🔄 Лампы: \(updatedLights.map { $0.metadata.name })")
                self?.assignedLights = updatedLights
                print("✅ EnvironmentView будет обновлен с \(updatedLights.count) лампами")
            }
            .store(in: &cancellables)
        
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

// MARK: - Extensions

extension EnvironmentViewModel {
    /// Создать mock ViewModel для превью
    static func createMock() -> EnvironmentViewModel {
        let mockAppViewModel = AppViewModel(dataPersistenceService: nil)
        let mockDataService = DataPersistenceService.createMock()
        return EnvironmentViewModel(
            appViewModel: mockAppViewModel, 
            dataPersistenceService: mockDataService
        )
    }
}
