//
//  PresetColorsFactory.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 2.09.2025.
//

import Foundation
import SwiftUI

// MARK: - Preset Colors Factory

/// Фабрика для создания цветовых пресетов
/// Элегантное решение вместо длинных списков инициализации
struct PresetColorsFactory {
    
    // MARK: - Color Preset Definitions
    
    /// Определения цветовых пресетов для первой секции Pastel
    private static let pastelSection1Presets: [String: [String]] = [
        "Golden Haze": ["#FCC474", "#FFB836", "#E8D1AD", "#DAA520", "#DEB887"],
        "Dawn Dunes": ["#F4A460", "#D2B48C", "#C68E17", "#DEB887", "#F0E68C"],
        "Whispering Sands": ["#F5F5DC", "#CE9158", "#FFD4A3", "#FAE7E6", "#ECBC92"],
        "Echoed Patterns": ["#E8875A", "#CD853F", "#F4A460", "#D2691E", "#ECAA7F"],
        "Fading Blossoms": ["#FFA07A", "#FFB6C1", "#FFDAB9", "#FFE4E1", "#FAEBD7"],
        "Luminous Drift": ["#E6E6FA", "#D8BFD8", "#F0F8FF", "#B0E0E6", "#ADD8E6"],
        "Skybound Serenity": ["#FFB6C1", "#FFA07A", "#FAEBD7", "#F0CA8C", "#AAD7F6"],
        "Horizon Glow": ["#DB9DCF", "#F9C1B1", "#FAEFDD", "#7E6A98", "#E2A6A4"],
        "Ethereal Metropolis": ["#F7D0D4", "#EE93B1", "#C77AAB", "#F872A0", "#EFAFC9"],
        "Verdant Mist": ["#D3DFFF", "#F3BDA2", "#F9C2E5", "#FA8C8C", "#ECC1AF"]
    ]
    
    // MARK: - Factory Methods
    
    /// Создает массив PresetSceneColor из hex цветов
    /// - Parameter hexColors: Массив HEX цветов
    /// - Returns: Массив PresetSceneColor с автоматическими приоритетами
    static func createPresetColors(from hexColors: [String]) -> [PresetSceneColor] {
        return hexColors.enumerated().map { index, hexColor in
            PresetSceneColor(hexColor: hexColor, priority: index)
        }
    }
    
    /// Получить цвета пресета по имени сцены
    /// - Parameter sceneName: Имя сцены
    /// - Returns: Массив PresetSceneColor или пустой массив
    static func getPresetColors(for sceneName: String) -> [PresetSceneColor] {
        guard let hexColors = pastelSection1Presets[sceneName] else {
            print("⚠️ PresetColorsFactory: Цвета для сцены '\(sceneName)' не найдены")
            return []
        }
        
        return createPresetColors(from: hexColors)
    }
    
    /// Создать сцену с автоматическими цветами пресета
    /// - Parameters:
    ///   - name: Название сцены
    ///   - imageAssetName: Имя ассета изображения
    ///   - section: Секция
    ///   - filterType: Тип фильтра
    ///   - isFavorite: Избранное
    /// - Returns: EnvironmentSceneEntity с цветами пресета
    static func createSceneWithPresetColors(
        name: String,
        imageAssetName: String,
        section: EnvironmentSection,
        filterType: EnvironmentFilterType,
        isFavorite: Bool
    ) -> EnvironmentSceneEntity {
        let presetColors = getPresetColors(for: name)
        
        return EnvironmentSceneEntity(
            name: name,
            imageAssetName: imageAssetName,
            section: section,
            filterType: filterType,
            isFavorite: isFavorite,
            presetColors: presetColors
        )
    }
    
    /// Проверить, поддерживает ли сцена цветовые пресеты
    /// - Parameter sceneName: Имя сцены
    /// - Returns: true если поддерживает
    static func supportsPresetColors(_ sceneName: String) -> Bool {
        return pastelSection1Presets[sceneName] != nil
    }
    
    /// Получить все поддерживаемые сцены с пресетами
    /// - Returns: Массив имен сцен
    static func getAllSupportedScenes() -> [String] {
        return Array(pastelSection1Presets.keys).sorted()
    }
}

// MARK: - Extensions

extension PresetSceneColor {
    /// Удобный статический метод создания с автоматическим ID
    static func create(hexColor: String, priority: Int) -> PresetSceneColor {
        return PresetSceneColor(id: UUID().uuidString, hexColor: hexColor, priority: priority)
    }
}

// MARK: - Color Palette Utilities

extension PresetColorsFactory {
    
    /// Создать палитру цветов для предварительного просмотра
    /// - Parameter sceneName: Имя сцены
    /// - Returns: Массив SwiftUI Color
    static func createColorPalette(for sceneName: String) -> [Color] {
        return getPresetColors(for: sceneName).map { $0.color }
    }
    
    /// Получить доминирующий цвет сцены
    /// - Parameter sceneName: Имя сцены
    /// - Returns: Основной цвет сцены
    static func getDominantColor(for sceneName: String) -> Color? {
        return getPresetColors(for: sceneName).first?.color
    }
    
    /// Создать градиент из цветов пресета
    /// - Parameter sceneName: Имя сцены
    /// - Returns: LinearGradient для UI
    static func createGradient(for sceneName: String) -> LinearGradient {
        let colors = createColorPalette(for: sceneName)
        
        if colors.isEmpty {
            return LinearGradient(
                colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
