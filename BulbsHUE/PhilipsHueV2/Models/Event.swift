//
//  Event.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI

/// Событие от потока событий
struct HueEvent: Codable {
    /// ID события
    var id: String?
    
    /// Время создания
    var creationtime: Date?
    
    /// Тип события (update, add, delete)
    var type: String?
    
    /// Данные события
    var data: [EventData]?
}

/// Данные события
struct EventData: Codable {
    /// ID ресурса
    var id: String?
    
    /// Тип ресурса
    var type: String?
    
    /// Владелец
    var owner: ResourceIdentifier?
    
    /// Обновленные данные (зависит от типа)
    var motion: MotionState?
    var on: OnState?
    var dimming: Dimming?
    var color: HueColor?
    var color_temperature: ColorTemperature?
    var button: ButtonState?
    var temperature: TemperatureState?
    var light_level: LightLevelState?
}

/// Состояние температуры
struct TemperatureState: Codable {
    /// Температура в сотых долях градуса
    var temperature: Int?
    
    /// Валидность
    var temperature_valid: Bool?
}

/// Состояние освещенности
struct LightLevelState: Codable {
    /// Уровень освещенности в люксах
    var light_level: Int?
    
    /// Валидность
    var light_level_valid: Bool?
}
