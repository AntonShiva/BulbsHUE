//
//  EnvironmentBulbsViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import SwiftUI
import Combine
import Observation
import Foundation

// MARK: - Environment Bulbs View Model

/// ViewModel для экрана выбора сцен окружения
/// Управляет состоянием фильтров, секций и списком сцен
@MainActor
@Observable
class EnvironmentBulbsViewModel  {
    
    // MARK: - Published Properties
    
    /// Выбранный фильтр (Color Picker, Pastel, Bright)
    var selectedFilterTab: EnvironmentFilterType = .pastel
    
    /// Выбранная секция (Section 1, 2, 3)
    var selectedSection: EnvironmentSection = .section1
    
    /// Активен ли фильтр избранного
    var isFavoriteFilterActive = false
    
    /// Включен ли основной свет
    var isMainLightOn = true
    
    /// Активен ли режим солнца
    var isSunModeActive = false
    
    /// Сцены для текущего выбранного фильтра и секции
    var currentScenes: [EnvironmentSceneEntity] = []
    
    /// Состояние загрузки
    var isLoading = false
    
    /// Ошибка, если произошла
    var error: Error?
    
    // MARK: - Dependencies
    
    private let environmentScenesUseCase: EnvironmentScenesUseCaseProtocol
    private let presetColorService: PresetColorService
    private let roomControlColorService: RoomControlColorService
    private weak var navigationManager: NavigationManager?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        environmentScenesUseCase: EnvironmentScenesUseCaseProtocol = DIContainer.shared.environmentScenesUseCase,
        presetColorService: PresetColorService = DIContainer.shared.presetColorService,
        roomControlColorService: RoomControlColorService = DIContainer.shared.roomControlColorService,
        navigationManager: NavigationManager? = NavigationManager.shared
    ) {
        self.environmentScenesUseCase = environmentScenesUseCase
        self.presetColorService = presetColorService
        self.roomControlColorService = roomControlColorService
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
                let _ = try await environmentScenesUseCase.selectScene(sceneId: scene.id)
                // Обновляем только текущие отображаемые сцены
                await loadScenesForCurrentSelection()
                
                // Если сцена содержит цвета пресета, применяем их к лампам
                if scene.hasPresetColors {
                    await applyPresetColors(from: scene)
                }
            } catch {
                self.error = error
            }
        }
    }
    
    /// Применить цвета пресета к целевым лампам
    @MainActor
    private func applyPresetColors(from scene: EnvironmentSceneEntity) async {
        guard let navigationManager = navigationManager else { return }
        
        do {
            // Определяем целевые лампы в зависимости от контекста
            if let targetLight = navigationManager.targetLightForColorChange {
                // Применяем к одной лампе - используем первый цвет
                try await presetColorService.applyPresetColor(
                    from: scene,
                    to: targetLight.id,
                    colorIndex: 0
                )
                print("✅ Применен цвет пресета '\(scene.name)' к лампе '\(targetLight.metadata.name)'")
                
            } else if let targetRoom = navigationManager.targetRoomForColorChange {
                // Применяем к комнате - распределяем цвета по лампам
                try await presetColorService.applyPresetColors(
                    from: scene,
                    to: targetRoom.lightIds,
                    strategy: .adaptive
                )
                print("✅ Применены цвета пресета '\(scene.name)' к комнате '\(targetRoom.name)'")
                
                // ✅ Сохраняем доминирующий цвет пресета в RoomColorStateService
                if let dominantColor = PresetColorsFactory.getDominantColor(for: scene.name) {
                    RoomColorStateService.shared.setRoomColor(targetRoom.id, color: dominantColor)
                }
                
                // ✅ Обновляем цвет контрола комнаты через сервис
                Task {
                    await roomControlColorService.updateRoomColor(roomId: targetRoom.id, sceneName: scene.name)
                }
            }
        } catch {
            print("❌ Ошибка применения цветов пресета: \(error.localizedDescription)")
            self.error = error
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
