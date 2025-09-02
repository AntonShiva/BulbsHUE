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
    
    /// Определения цветовых пресетов для второй секции Pastel
    private static let pastelSection2Presets: [String: [String]] = [
        "Celestial Whispers": ["#F0CC95", "#ECBC95", "#BFA55C", "#8B8D3F", "#939C53"],
        "Silent Ridges": ["#F2CFB2", "#FDE8CD", "#89A78E", "#C5A68A", "#91CFBE"],
        "Soaring Shadows": ["#F4A460", "#D2B48C", "#C68E17", "#DEB887", "#F0E68C"],
        "Tranquil Shoreline": ["#9CCAC5", "#70B7B3", "#A5C2C2", "#D2D6D7", "#52827B"],
        "Gilded Glow": ["#294134", "#4A5046", "#69755D", "#708D83", "#9DA79D"],
        "Midnight Echo": ["#10473C", "#0C3930", "#588983", "#026F58", "#669589"],
        "Evergreen Veil": ["#BAC6C3", "#909E9D", "#526F6D", "#81AAA3", "#5F9E83"],
        "Mirror Lake": ["#85CED1", "#48BFC2", "#A0CD9B", "#158689", "#68A68F"],
        "Aurora Pulse": ["#617E44", "#949A80", "#D9D7BF", "#BFC9A4", "#445F36"],
        "Whispering Wilds": ["#485830", "#869883", "#6B824A", "#36592B", "#67796C"]
    ]
    
    /// Определения цветовых пресетов для третьей секции Pastel
    private static let pastelSection3Presets: [String: [String]] = [
        "Violet Mist": ["#CBB1E3", "#A589C8", "#9D6DC9", "#CAADE1", "#ACA5E3"],
        "Azure Peaks": ["#8EBDCF", "#5AA6C4", "#408FB2", "#A7CDE0", "#01638D"],
        "Crystal Drift": ["#294134", "#4A5046", "#69755D", "#708D83", "#9DA79D"],
        "Twilight Pines": ["#BAC6C3", "#909E9D", "#526F6D", "#81AAA3", "#5F9E83"],
        "Layered Tranquility": ["#617E44", "#949A80", "#D9D7BF", "#BFC9A4", "#445F36"],
        "Lavender Horizon": ["#F2CFB2", "#FDE8CD", "#89A78E", "#C5A68A", "#91CFBE"],
        "Frozen Veins": ["#91A8DF", "#28497E", "#6689CB", "#9EBEFB", "#C2D1FF"],
        "Eclipsed Glow": ["#10473C", "#0C3930", "#588983", "#026F58", "#669589"],
        "Phantom Summits": ["#C6E4EB", "#8DC7D8", "#D8DBD4", "#A1C7CF", "#B5D3D7"],
        "Echoed Fog": ["#99C1D1", "#177D9E", "#6AAEC9", "#4395B3", "#79ADC2"]
    ]
    
    /// Определения цветовых пресетов для первой секции Bright
    private static let brightSection1Presets: [String: [String]] = [
        "Golden Horizon": ["#FFA875", "#FF9500", "#FFC66F", "#E28320", "#FBC93D"],
        "Rosé Quartz": ["#FF5291", "#FF87B3", "#FF5291", "#FF307B", "#FF5D98"],
        "Molten Ember": ["#FF7521", "#FF96FF", "#2282FF", "#FFCDA6", "#FF4AFF"],
        "Lemon Mirage": ["#BAC6C3", "#909E9D", "#526F6D", "#81AAA3", "#5F9E83"],
        "Solar Flare": ["#617E44", "#949A80", "#D9D7BF", "#BFC9A4", "#445F36"],
        "Velvet Glow": ["#FD9DAB", "#FDCDF8", "#E3A4FF", "#AE69CF", "#E893BF"],
        "Crimson Lanterns": ["#FF623A", "#FF2E44", "#FF1515", "#F35F5A", "#FA2233"],
        "Canyon Echo": ["#FF8733", "#D95900", "#FFA86C", "#FFD0AF", "#FF612D"],
        "Wild Bloom": ["#69D9FF", "#FFC037", "#FA7801", "#0ABF83", "#FFC041"],
        "Honey Drip": ["#E57148", "#FADC00", "#FF8669", "#FFA8A8", "#F9CB00"]
    ]
    
    /// Определения цветовых пресетов для второй секции Bright
    private static let brightSection2Presets: [String: [String]] = [
        "Emerald Veil": ["#21C36C", "#BAEBAA", "#89DBC8", "#1EDB3E", "#3CA06D"],
        "Lucky Charm": ["#A7FF48", "#53D131", "#BAFF6F", "#8CEE22", "#48FF48"],
        "Geometric Mirage": ["#17EF14", "#6FC7FF", "#2282FF", "#A6ECFF", "#42CBBF"],
        "Citrus Harvest": ["#CDFF8F", "#88FF86", "#FFF477", "#BEFF3B", "#A1EB0B"],
        "Aurora Echo": ["#6AFFBC", "#BAFFE2", "#21E3A1", "#57FBB6", "#45E4B7"],
        "Jade Fracture": ["#4FE892", "#21BF61", "#CEFFE7", "#8BFFB7", "#50D880"],
        "Verdant Passage": ["#88E76F", "#B7FF9F", "#2BB788", "#11815E", "#6DE75C"],
        "Lego Labyrinth": ["#8EC933", "#ACDB64", "#8AC52F", "#C1FF62", "#AAF03F"],
        "Neon Zest": ["#D5FF69", "#B7F31D", "#EAFFB5", "#95CF18", "#CBFF46"],
        "Celestial Glow": ["#00D524", "#24E055", "#008D26", "#096439", "#007326"]
    ]
    
    /// Определения цветовых пресетов для третьей секции Bright
    private static let brightSection3Presets: [String: [String]] = [
        "Neon Abyss": ["#04F0BB", "#41C9FF", "#1647C4", "#04EFF9", "#B3FEDD"],
        "Serene Waves": ["#36A8FF", "#297CEF", "#08D4F3", "#59AFFF", "#0FB8F5"],
        "Twilight Bloom": ["#B1B4FD", "#946BFB", "#DD97F2", "#B09DFB", "#A394FF"],
        "Nebula Mirage": ["#FF3B88", "#FF6FE9", "#FF6292", "#6528BB", "#E9279C"],
        "Sapphire Glow": ["#4B60FF", "#4977FF", "#0242F4", "#0436B2", "#7196FF"],
        "Crystal Tide": ["#00E8FF", "#7FE3FF", "#00D4FF", "#CBFAFF", "#00FFF6"],
        "Phantom Drift": ["#AA00FF", "#FED2C5", "#513FDD", "#C95CFF", "#FD95FF"],
        "Lunar Medusa": ["#3A99FF", "#2C66E9", "#93C7FA", "#0050FF", "#266CE8"],
        "Frozen Whispers": ["#B7EDFF", "#60D6FF", "#21C4FF", "#7AD5FF", "#DDF7FF"],
        "Blooming Depths": ["#3034D1", "#65D4FF", "#BDFFE9", "#5756EB", "#48C4FF"]
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
        // Сначала проверяем первую секцию Pastel
        if let hexColors = pastelSection1Presets[sceneName] {
            return createPresetColors(from: hexColors)
        }
        
        // Затем проверяем вторую секцию Pastel
        if let hexColors = pastelSection2Presets[sceneName] {
            return createPresetColors(from: hexColors)
        }
        
        // Затем проверяем третью секцию Pastel
        if let hexColors = pastelSection3Presets[sceneName] {
            return createPresetColors(from: hexColors)
        }
        
        // Затем проверяем первую секцию Bright
        if let hexColors = brightSection1Presets[sceneName] {
            return createPresetColors(from: hexColors)
        }
        
        // Затем проверяем вторую секцию Bright
        if let hexColors = brightSection2Presets[sceneName] {
            return createPresetColors(from: hexColors)
        }
        
        // Затем проверяем третью секцию Bright
        if let hexColors = brightSection3Presets[sceneName] {
            return createPresetColors(from: hexColors)
        }
        
        print("⚠️ PresetColorsFactory: Цвета для сцены '\(sceneName)' не найдены")
        return []
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
        return pastelSection1Presets[sceneName] != nil || 
               pastelSection2Presets[sceneName] != nil || 
               pastelSection3Presets[sceneName] != nil ||
               brightSection1Presets[sceneName] != nil ||
               brightSection2Presets[sceneName] != nil ||
               brightSection3Presets[sceneName] != nil
    }
    
    /// Получить все поддерживаемые сцены с пресетами
    /// - Returns: Массив имен сцен
    static func getAllSupportedScenes() -> [String] {
        let section1Scenes = Array(pastelSection1Presets.keys)
        let section2Scenes = Array(pastelSection2Presets.keys)
        let section3Scenes = Array(pastelSection3Presets.keys)
        let brightSection1Scenes = Array(brightSection1Presets.keys)
        let brightSection2Scenes = Array(brightSection2Presets.keys)
        let brightSection3Scenes = Array(brightSection3Presets.keys)
        return (section1Scenes + section2Scenes + section3Scenes + brightSection1Scenes + brightSection2Scenes + brightSection3Scenes).sorted()
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
