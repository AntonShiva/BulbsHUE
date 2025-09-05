//
//  PresetColorViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 9/05/25.
//

import SwiftUI
import Combine

@MainActor
class PresetColorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: PresetColorTab = .statics
    @Published var brightness: Double = 50.0
    @Published var isFavorite: Bool = false
    
    // Dynamic settings
    @Published var dynamicBrightness: Double = 50.0
    @Published var selectedStyle: StyleType = .classic
    @Published var selectedIntensity: IntensityType = .middle
    @Published var isStyleExpanded: Bool = false
    @Published var isIntensityExpanded: Bool = false
    
    // MARK: - Private Properties
    private let scene: EnvironmentSceneEntity?
    private let environmentScenesUseCase: EnvironmentScenesUseCaseProtocol
    private var lightingColorService: LightingManaging?
    private let navigationManager: NavigationManager
    
    // Дебаунсинг для обновлений яркости
    private var brightnessTask: Task<Void, Never>?
    private var dynamicBrightnessTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(scene: EnvironmentSceneEntity? = nil) {
        self.scene = scene
        self.environmentScenesUseCase = DIContainer.shared.environmentScenesUseCase
        self.navigationManager = NavigationManager.shared
        
        // Устанавливаем начальные значения из сцены
        if let scene = scene {
            self.isFavorite = scene.isFavorite
        }
    }
    
    // MARK: - Configuration
    
    /// Конфигурирует ViewModel с AppViewModel (вызывается из View.onAppear)
    func configure(with appViewModel: AppViewModel) {
        let lightControlService = LightControlService(appViewModel: appViewModel)
        self.lightingColorService = LightingColorService(
            lightControlService: lightControlService,
            appViewModel: appViewModel
        )
    }
    
    // MARK: - Computed Properties
    
    /// Прозрачность для BrightnessSlider в динамическом режиме
    var dynamicBrightnessOpacity: Double {
        return (isStyleExpanded || isIntensityExpanded) ? 0.02 : 1.0
    }
    
    /// Прозрачность для StyleSettingView
    var styleOpacity: Double {
        return isIntensityExpanded ? 0.02 : 1.0
    }
    
    /// Прозрачность для IntensitySettingView
    var intensityOpacity: Double {
        return isStyleExpanded ? 0.02 : 1.0
    }
    
    // MARK: - Public Methods
    
    /// Переключить статус избранного
    func toggleFavorite() {
        guard let scene = scene else { return }
        
        Task {
            do {
                let updatedScene = try await environmentScenesUseCase.toggleFavorite(sceneId: scene.id)
                await MainActor.run {
                    self.isFavorite = updatedScene.isFavorite
                }
            } catch {
                print("Error toggling favorite: \(error)")
            }
        }
    }
    
    /// Установить яркость с дебаунсом для статического режима
    func setBrightnessThrottled(_ value: Double) {
        brightness = value
        
        // Отменяем предыдущую задачу
        brightnessTask?.cancel()
        
        // Создаем новую задачу с дебаунсом
        brightnessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms дебаунс
            
            guard !Task.isCancelled else { return }
            await self?.applyBrightnessToTargetLights(value)
        }
    }
    
    /// Зафиксировать финальное значение яркости для статического режима
    func commitBrightness(_ value: Double) {
        brightnessTask?.cancel()
        brightness = value
        
        Task { [weak self] in
            await self?.applyBrightnessToTargetLights(value)
        }
    }
    
    /// Установить динамическую яркость с дебаунсом
    func setDynamicBrightnessThrottled(_ value: Double) {
        dynamicBrightness = value
        
        // Отменяем предыдущую задачу
        dynamicBrightnessTask?.cancel()
        
        // Создаем новую задачу с дебаунсом
        dynamicBrightnessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms дебаунс
            
            guard !Task.isCancelled else { return }
            await self?.applyBrightnessToTargetLights(value)
        }
    }
    
    /// Зафиксировать финальное значение динамической яркости
    func commitDynamicBrightness(_ value: Double) {
        dynamicBrightnessTask?.cancel()
        dynamicBrightness = value
        
        Task { [weak self] in
            await self?.applyBrightnessToTargetLights(value)
        }
    }
    
    // MARK: - Private Methods
    
    /// Применить яркость к целевым лампам (аналогично ItemControl и RoomControl)
    private func applyBrightnessToTargetLights(_ brightnessValue: Double) async {
        guard let lightingService = lightingColorService else {
            print("⚠️ PresetColorViewModel: LightingColorService недоступен")
            return
        }
        
        do {
            // Определяем целевые лампы в зависимости от контекста NavigationManager
            if let targetRoom = navigationManager.targetRoomForColorChange {
                // ИСПРАВЛЕНИЕ: Применяем яркость ко ВСЕЙ КОМНАТЕ (всем лампам в ней)
                try await lightingService.setBrightness(for: targetRoom, brightness: brightnessValue)
                print("✅ PresetColor: Яркость комнаты '\(targetRoom.name)' (\(targetRoom.lightIds.count) ламп) изменена на \(brightnessValue)%")
                
            } else if let targetLight = navigationManager.targetLightForColorChange {
                // Применяем к одной лампе (если открыто из ItemControl)
                try await lightingService.setBrightness(for: targetLight, brightness: brightnessValue)
                print("✅ PresetColor: Яркость лампы '\(targetLight.metadata.name)' изменена на \(brightnessValue)%")
                
            } else {
                // Если нет целевых объектов в NavigationManager, применяем ко всем доступным лампам
                print("ℹ️ PresetColor: Целевые лампы/комнаты не указаны в NavigationManager")
                
                // Fallback: можно добавить поддержку "глобального" режима
                // Пока что просто логируем, что контекст не найден
                print("ℹ️ PresetColor: Для применения яркости нужно открыть EnvironmentBulbsView через ItemControl или RoomControl")
            }
        } catch {
            print("❌ PresetColor: Ошибка изменения яркости - \(error.localizedDescription)")
        }
    }
    
    func savePresetColor() {
        switch selectedTab {
        case .statics:
            print("Saving static preset color settings - brightness: \(brightness)%")
        case .dynamic:
            print("Saving dynamic preset color settings:")
            print("- Brightness: \(dynamicBrightness)%")
            print("- Style: \(selectedStyle.displayName)")
            print("- Intensity: \(selectedIntensity.displayName)")
        }
    }
    
    deinit {
        // Отменяем все активные задачи при деинициализации
        brightnessTask?.cancel()
        dynamicBrightnessTask?.cancel()
    }
}