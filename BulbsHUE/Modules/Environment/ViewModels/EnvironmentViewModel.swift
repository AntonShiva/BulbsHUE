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
@MainActor
class EnvironmentViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Список ламп с назначенными комнатами (архетипами)
    @Published var assignedLights: [Light] = []
    
    /// Статус загрузки данных
    @Published var isLoading: Bool = false
    
    /// Ошибка загрузки (если есть)
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    /// Ссылка на основной AppViewModel для доступа к данным
    private weak var appViewModel: AppViewModel?
    
    /// Подписки Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Инициализация с внедрением зависимости
    /// - Parameter appViewModel: Основной ViewModel приложения
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        setupObservers()
        loadAssignedLights()
    }
    
    // MARK: - Public Methods
    
    /// Принудительно обновить список ламп
    func refreshLights() {
        isLoading = true
        error = nil
        appViewModel?.lightsViewModel.loadLights()
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
        
        // Подписываемся на изменения списка ламп
        appViewModel.lightsViewModel.$lights
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lights in
                self?.updateAssignedLights(lights)
            }
            .store(in: &cancellables)
        
        // Подписываемся на состояние загрузки
        appViewModel.lightsViewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // Подписываемся на ошибки
        appViewModel.lightsViewModel.$error
            .receive(on: DispatchQueue.main)
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
    }
    
    /// Обновить список назначенных ламп
    /// - Parameter lights: Полный список ламп
    private func updateAssignedLights(_ lights: [Light]) {
        // Фильтруем только лампы с назначенными архетипами (комнатами)
        assignedLights = lights.filter { light in
            light.metadata.archetype != nil
        }
        
        // Сортируем по имени для стабильного отображения
        assignedLights.sort { $0.metadata.name < $1.metadata.name }
    }
    
    /// Загрузить назначенные лампы
    private func loadAssignedLights() {
        guard let appViewModel = appViewModel else { return }
        
        // Если лампы уже загружены, обновляем сразу
        if !appViewModel.lightsViewModel.lights.isEmpty {
            updateAssignedLights(appViewModel.lightsViewModel.lights)
        }
    }
}

// MARK: - Extensions

extension EnvironmentViewModel {
    /// Создать mock ViewModel для превью
    static func createMock() -> EnvironmentViewModel {
        let mockAppViewModel = AppViewModel()
        return EnvironmentViewModel(appViewModel: mockAppViewModel)
    }
}
