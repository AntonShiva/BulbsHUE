//
//  EnvironmentBulbsViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import SwiftUI
import Combine

// MARK: - Environment Bulbs View Model

/// ViewModel для экрана выбора сцен окружения
/// Управляет состоянием фильтров, секций и списком сцен
@MainActor
final class EnvironmentBulbsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Выбранный фильтр (Color Picker, Pastel, Bright)
    @Published var selectedFilterTab: EnvironmentFilterType = .pastel
    
    /// Выбранная секция (Section 1, 2, 3)
    @Published var selectedSection: EnvironmentSection = .section1
    
    /// Активен ли фильтр избранного
    @Published var isFavoriteFilterActive = false
    
    /// Включен ли основной свет
    @Published var isMainLightOn = true
    
    /// Активен ли режим солнца
    @Published var isSunModeActive = false
    
    /// Сцены для текущего выбранного фильтра и секции
    @Published var currentScenes: [EnvironmentSceneEntity] = []
    
    /// Состояние загрузки
    @Published var isLoading = false
    
    /// Ошибка, если произошла
    @Published var error: Error?
    
    // MARK: - Dependencies
    
    private let environmentScenesUseCase: EnvironmentScenesUseCaseProtocol
    private weak var navigationManager: NavigationManager?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(environmentScenesUseCase: EnvironmentScenesUseCaseProtocol, navigationManager: NavigationManager? = nil) {
        self.environmentScenesUseCase = environmentScenesUseCase
        self.navigationManager = navigationManager
        setupBindings()
        loadInitialScenes()
    }
    
    // MARK: - Public Methods
    
    /// Выбрать фильтр и обновить сцены
    func selectFilterTab(_ tab: EnvironmentFilterType) {
        selectedFilterTab = tab
        Task {
            await loadScenesForCurrentSelection()
        }
    }
    
    /// Выбрать секцию и обновить сцены
    func selectSection(_ section: EnvironmentSection) {
        selectedSection = section
        Task {
            await loadScenesForCurrentSelection()
        }
    }
    
    /// Переключить фильтр избранного
    func toggleFavoriteFilter() {
        isFavoriteFilterActive.toggle()
        Task {
            await loadScenesForCurrentSelection()
        }
    }
    
    /// Переключить основной свет
    func toggleMainLight() {
        isMainLightOn.toggle()
        // TODO: Добавить логику управления светом через соответствующий UseCase
    }
    
    /// Переключить режим солнца
    func toggleSunMode() {
        isSunModeActive.toggle()
        // TODO: Добавить логику управления яркостью через соответствующий UseCase
    }
    
    /// Выбрать сцену
    func selectScene(_ scene: EnvironmentSceneEntity) {
        Task {
            do {
                let updatedScenes = try await environmentScenesUseCase.selectScene(sceneId: scene.id)
                // Обновляем только текущие отображаемые сцены
                await loadScenesForCurrentSelection()
            } catch {
                self.error = error
            }
        }
    }
    
    /// Переключить статус избранного для сцены
    func toggleSceneFavorite(_ scene: EnvironmentSceneEntity) {
        Task {
            do {
                let _ = try await environmentScenesUseCase.toggleFavorite(sceneId: scene.id)
                await loadScenesForCurrentSelection()
            } catch {
                self.error = error
            }
        }
    }
    
    /// Открыть экран редактирования пресета
    func editPreset(_ scene: EnvironmentSceneEntity) {
        navigationManager?.showPresetColorEdit(for: scene)
    }
    
    // MARK: - Private Methods
    
    /// Настройка подписок на изменения
    private func setupBindings() {
        // Можно добавить дополнительную логику для реакции на изменения состояния
    }
    
    /// Загрузка начальных сцен
    private func loadInitialScenes() {
        Task {
            await loadScenesForCurrentSelection()
        }
    }
    
    /// Загрузка сцен для текущего выбранного фильтра и секции
    private func loadScenesForCurrentSelection() async {
        isLoading = true
        error = nil
        
        do {
            let scenes = try await environmentScenesUseCase.getScenes(
                for: selectedFilterTab,
                section: selectedSection,
                favoritesOnly: isFavoriteFilterActive
            )
            
            await MainActor.run {
                self.currentScenes = scenes
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                self.currentScenes = []
            }
        }
    }
}

// MARK: - Convenience Init for DI

extension EnvironmentBulbsViewModel {
    /// Convenience инициализатор с зависимостями через DI Container
    convenience init() {
        let useCase = DIContainer.shared.environmentScenesUseCase
        let navigationManager = NavigationManager.shared
        self.init(environmentScenesUseCase: useCase, navigationManager: navigationManager)
    }
}
