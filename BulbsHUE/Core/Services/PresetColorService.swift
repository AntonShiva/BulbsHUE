//
//  PresetColorService.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 2.09.2025.
//

import SwiftUI
import Combine

// MARK: - Preset Color Service Protocol

/// Протокол для применения цветов пресетов к лампам
protocol PresetColorServiceProtocol {
    /// Применить цвета пресета к лампам в комнате
    /// - Parameters:
    ///   - scene: Сцена с пресетными цветами
    ///   - lightIds: ID ламп для применения цветов
    ///   - strategy: Стратегия распределения цветов
    func applyPresetColors(
        from scene: EnvironmentSceneEntity,
        to lightIds: [String],
        strategy: ColorDistributionStrategy
    ) async throws
    
    /// Применить цвета пресета к конкретной лампе
    /// - Parameters:
    ///   - scene: Сцена с пресетными цветами
    ///   - lightId: ID лампы
    ///   - colorIndex: Индекс цвета из пресета (0-4)
    func applyPresetColor(
        from scene: EnvironmentSceneEntity,
        to lightId: String,
        colorIndex: Int
    ) async throws
}

// MARK: - Preset Color Service Implementation

/// Сервис для применения цветов пресетов к лампам
/// Следует принципам SOLID - Single Responsibility и Dependency Inversion
@MainActor
final class PresetColorService: PresetColorServiceProtocol {
    
    // MARK: - Dependencies
    
    private let lightingColorService: LightingManaging
    private let lightColorStateService: LightColorStateService
    private weak var appViewModel: AppViewModel?
    
    // MARK: - Initialization
    
    init(
        lightingColorService: LightingManaging,
        lightColorStateService: LightColorStateService = .shared,
        appViewModel: AppViewModel?
    ) {
        self.lightingColorService = lightingColorService
        self.lightColorStateService = lightColorStateService
        self.appViewModel = appViewModel
    }
    
    // MARK: - Public Methods
    
    func applyPresetColors(
        from scene: EnvironmentSceneEntity,
        to lightIds: [String],
        strategy: ColorDistributionStrategy = .adaptive
    ) async throws {
        guard !scene.presetColors.isEmpty else {
            print("⚠️ PresetColorService: Сцена '\(scene.name)' не содержит цветов")
            return
        }
        
        guard !lightIds.isEmpty else {
            print("⚠️ PresetColorService: Не указаны лампы для применения цветов")
            return
        }
        
        // Получаем распределение цветов по лампам
        let distributedColors = strategy.distributeColors(scene.presetColors, forLightCount: lightIds.count)
        
        print("🎨 PresetColorService: Применяем цвета пресета '\(scene.name)' к \(lightIds.count) лампам")
        print("🎨 Стратегия распределения: \(strategy)")
        
        // Применяем цвета к каждой лампе асинхронно
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, lightId) in lightIds.enumerated() {
                guard index < distributedColors.count else { continue }
                
                let color = distributedColors[index]
                
                group.addTask { [weak self] in
                    try await self?.applyColorToLight(lightId: lightId, color: color)
                }
            }
            
            // Ждем завершения всех задач
            for try await _ in group { }
        }
        
        print("✅ PresetColorService: Цвета успешно применены к \(lightIds.count) лампам")
    }
    
    func applyPresetColor(
        from scene: EnvironmentSceneEntity,
        to lightId: String,
        colorIndex: Int
    ) async throws {
        guard colorIndex >= 0 && colorIndex < scene.presetColors.count else {
            throw PresetColorServiceError.invalidColorIndex(colorIndex)
        }
        
        let presetColor = scene.presetColors[colorIndex]
        let color = presetColor.color
        
        print("🎨 PresetColorService: Применяем цвет \(presetColor.hexColor) к лампе \(lightId)")
        
        try await applyColorToLight(lightId: lightId, color: color)
        
        print("✅ PresetColorService: Цвет успешно применен к лампе \(lightId)")
    }
    
    // MARK: - Private Methods
    
    /// Применяет цвет к конкретной лампе
    private func applyColorToLight(lightId: String, color: Color) async throws {
        guard let appViewModel = appViewModel else {
            throw PresetColorServiceError.appViewModelNotAvailable
        }
        
        // Находим лампу
        guard let light = appViewModel.lightsViewModel.lights.first(where: { $0.id == lightId }) else {
            throw PresetColorServiceError.lightNotFound(lightId)
        }
        
        // Применяем цвет через LightingColorService немедленно
        try await lightingColorService.setColorImmediate(for: light, color: color)
        
        // Сохраняем состояние цвета в LightColorStateService
        lightColorStateService.setLightColor(lightId, color: color)
    }
}

// MARK: - Preset Color Service Errors

/// Ошибки сервиса цветов пресетов
enum PresetColorServiceError: Error, LocalizedError {
    case invalidColorIndex(Int)
    case lightNotFound(String)
    case appViewModelNotAvailable
    case noColorsInPreset
    
    var errorDescription: String? {
        switch self {
        case .invalidColorIndex(let index):
            return "Неверный индекс цвета: \(index)"
        case .lightNotFound(let lightId):
            return "Лампа с ID \(lightId) не найдена"
        case .appViewModelNotAvailable:
            return "AppViewModel недоступен"
        case .noColorsInPreset:
            return "Пресет не содержит цветов"
        }
    }
}

// MARK: - Extensions

extension EnvironmentSceneEntity {
    /// Проверяет, содержит ли сцена цвета пресета
    var hasPresetColors: Bool {
        return !presetColors.isEmpty
    }
    
    /// Возвращает основной (первый) цвет пресета
    var primaryColor: Color? {
        return presetColors.first?.color
    }
    
    /// Возвращает все цвета пресета как SwiftUI Colors
    var allColors: [Color] {
        return presetColors.map { $0.color }
    }
}
