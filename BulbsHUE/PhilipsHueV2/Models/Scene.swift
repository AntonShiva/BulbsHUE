//
//  Scene.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// Модель сцены освещения
struct HueScene: Codable, Identifiable {
    /// Уникальный идентификатор сцены
    var id: String = UUID().uuidString
    
    /// Тип ресурса (всегда "scene")
    var type: String = "scene"
    
    /// Метаданные сцены
    var metadata: SceneMetadata = SceneMetadata()
    
    /// Группа, к которой привязана сцена
    var group: ResourceIdentifier?
    
    /// Действия сцены
    var actions: [HueSceneAction] = []
    
    /// Палитра цветов для сцены
    var palette: ScenePalette?
    
    /// Скорость динамической сцены
    var speed: Double?
    
    /// Флаг автоматического динамического режима
    var auto_dynamic: Bool?
}


/// Метаданные сцены
struct SceneMetadata: Codable {
    /// Название сцены
    var name: String = "Новая сцена"
    
    /// Изображение сцены
    var image: ResourceIdentifier?
}

/// Действие в сцене
struct HueSceneAction: Codable {
    /// Цель действия (лампа или группа)
    var target: ResourceIdentifier?
    
    /// Настройки действия
    var action: LightState?
}

/// Активация сцены
struct SceneActivation: Codable {
    var recall: RecallAction
}

/// Действие воспроизведения сцены
struct RecallAction: Codable {
    var action: String // "active"
}

/// Палитра сцены
struct ScenePalette: Codable {
    /// Цвета в палитре
    var colors: [PaletteColor]?
    
    /// Настройки яркости
    var dimming: [Dimming]?
    
    /// Цветовые температуры
    var color_temperature: [ColorTemperaturePalette]?
}

/// Цвет в палитре
struct PaletteColor: Codable {
    /// Цветовые координаты
    var color: HueColor?
    
    /// Настройки яркости
    var dimming: Dimming?
}

/// Цветовая температура в палитре
struct ColorTemperaturePalette: Codable {
    /// Значение цветовой температуры
    var color_temperature: ColorTemperature?
    
    /// Настройки яркости
    var dimming: Dimming?
}
