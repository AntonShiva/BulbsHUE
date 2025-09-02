//
//  EnvironmentScenesLocalDataSource.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import Foundation

// MARK: - Environment Scenes Local Data Source

/// Локальный источник данных для пресетов сцен окружения
final class EnvironmentScenesLocalDataSource {
    
    // MARK: - Public Methods
    
    /// Загружает предустановленные сцены
    func loadScenes() async -> [EnvironmentSceneEntity] {
        return await Task {
            return createPredefinedScenes()
        }.value
    }
    
    /// Обновляет сцену в локальном хранилище
    func updateScene(_ scene: EnvironmentSceneEntity) async {
        // В будущем здесь можно добавить сохранение в UserDefaults или Core Data
        // Пока что это просто placeholder для архитектуры
    }
    
    // MARK: - Private Methods
    
    /// Создает предустановленные сцены для всех фильтров и секций
    private func createPredefinedScenes() -> [EnvironmentSceneEntity] {
        var scenes: [EnvironmentSceneEntity] = []
        
        // MARK: - Pastel Scenes
        scenes.append(contentsOf: createPastelScenes())
        
        // MARK: - Bright Scenes  
        scenes.append(contentsOf: createBrightScenes())
        
        // MARK: - Color Picker Scenes
        scenes.append(contentsOf: createColorPickerScenes())
        
        return scenes
    }
}

// MARK: - Scene Creation Extensions

extension EnvironmentScenesLocalDataSource {
    
    /// Создает сцены для Pastel фильтра
    private func createPastelScenes() -> [EnvironmentSceneEntity] {
        return [
            // Section 1 - Pastel (с цветовыми пресетами)
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Golden Haze",
                imageAssetName: "Golden Haze",
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Dawn Dunes",
                imageAssetName: "Dawn Dunes",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Whispering Sands",
                imageAssetName: "Whispering Sands",
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Echoed Patterns",
                imageAssetName: "Echoed Patterns",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Fading Blossoms",
                imageAssetName: "Fading Blossoms",
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Luminous Drift",
                imageAssetName: "Luminous Drift",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Skybound Serenity",
                imageAssetName: "Skybound Serenity",
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Horizon Glow",
                imageAssetName: "Horizon Glow",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Ethereal Metropolis",
                imageAssetName: "Ethereal Metropolis",
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Verdant Mist",
                imageAssetName: "Verdant Mist",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            
            // Section 2 - Pastel (с цветовыми пресетами)
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Celestial Whispers",
                imageAssetName: "Celestial Whispers",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Silent Ridges",
                imageAssetName: "Silent Ridges",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Soaring Shadows",
                imageAssetName: "Soaring Shadows",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Tranquil Shoreline",
                imageAssetName: "Tranquil Shoreline",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Gilded Glow",
                imageAssetName: "Gilded Glow",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Midnight Echo",
                imageAssetName: "Midnight Echo",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Evergreen Veil",
                imageAssetName: "Evergreen Veil",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Mirror Lake",
                imageAssetName: "Mirror Lake",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Aurora Pulse",
                imageAssetName: "Aurora Pulse",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Whispering Wilds",
                imageAssetName: "Whispering Wilds",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            
            // Section 3 - Pastel (с цветовыми пресетами)
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Violet Mist",
                imageAssetName: "Violet Mist",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Lavender Horizon",
                imageAssetName: "Lavender Horizon",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Azure Peaks",
                imageAssetName: "Azure Peaks",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Frozen Veins",
                imageAssetName: "Frozen Veins",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Crystal Drift",
                imageAssetName: "Crystal Drift",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Eclipsed Glow",
                imageAssetName: "Eclipsed Glow",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Twilight Pines",
                imageAssetName: "Twilight Pines",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Phantom Summits",
                imageAssetName: "Phantom Summits",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Layered Tranquility",
                imageAssetName: "Layered Tranquility",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Echoed Fog",
                imageAssetName: "Echoed Fog",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            )
        ]
    }
    
    /// Создает сцены для Bright фильтра
    private func createBrightScenes() -> [EnvironmentSceneEntity] {
        return [
            // Section 1 - Bright (с цветовыми пресетами)
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Golden Horizon",
                imageAssetName: "Golden Horizon",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Velvet Glow",
                imageAssetName: "Velvet Glow",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Rosé Quartz",
                imageAssetName: "Rosé Quartz",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Crimson Lanterns",
                imageAssetName: "Crimson Lanterns",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Molten Ember",
                imageAssetName: "Molten Ember",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Canyon Echo",
                imageAssetName: "Canyon Echo",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Lemon Mirage",
                imageAssetName: "Lemon Mirage",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Wild Bloom",
                imageAssetName: "Wild Bloom",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Solar Flare",
                imageAssetName: "Solar Flare",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Honey Drip",
                imageAssetName: "Honey Drip",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            
            // Section 2 - Bright (с цветовыми пресетами)
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Emerald Veil",
                imageAssetName: "Emerald Veil",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Jade Fracture",
                imageAssetName: "Jade Fracture",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Lucky Charm",
                imageAssetName: "Lucky Charm",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Verdant Passage",
                imageAssetName: "Verdant Passage",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Geometric Mirage",
                imageAssetName: "Geometric Mirage",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Lego Labyrinth",
                imageAssetName: "Lego Labyrinth",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Citrus Harvest",
                imageAssetName: "Citrus Harvest",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Neon Zest",
                imageAssetName: "Neon Zest",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Aurora Echo",
                imageAssetName: "Aurora Echo",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Celestial Glow",
                imageAssetName: "Celestial Glow",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            
            // Section 3 - Bright (с цветовыми пресетами)
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Neon Abyss",
                imageAssetName: "Neon Abyss",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Blooming Depths",
                imageAssetName: "Blooming Depths",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Serene Waves",
                imageAssetName: "Serene Waves",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Crystal Tide",
                imageAssetName: "Crystal Tide",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Twilight Bloom",
                imageAssetName: "Twilight Bloom",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Phantom Drift",
                imageAssetName: "Phantom Drift",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Nebula Mirage",
                imageAssetName: "Nebula Mirage",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Lunar Medusa",
                imageAssetName: "Lunar Medusa",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Sapphire Glow",
                imageAssetName: "Sapphire Glow",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            PresetColorsFactory.createSceneWithPresetColors(
                name: "Frozen Whispers",
                imageAssetName: "Frozen Whispers",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            )
        ]
    }
    
    /// Создает сцены для Color Picker фильтра
    private func createColorPickerScenes() -> [EnvironmentSceneEntity] {
        return [
            // Section 1 - Color Picker
            EnvironmentSceneEntity(
                name: "Bright Red",
                imageAssetName: "re1",
                section: .section1,
                filterType: .colorPicker,
                isFavorite: true
            ),
            EnvironmentSceneEntity(
                name: "Ocean Blue",
                imageAssetName: "re2",
                section: .section1,
                filterType: .colorPicker,
                isFavorite: false
            ),
            EnvironmentSceneEntity(
                name: "Forest Green",
                imageAssetName: "re3",
                section: .section1,
                filterType: .colorPicker,
                isFavorite: true
            ),
            EnvironmentSceneEntity(
                name: "Sunset Orange",
                imageAssetName: "re4",
                section: .section1,
                filterType: .colorPicker,
                isFavorite: false
            )
        ]
    }
}
