//
//  Group.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// Модель группы (комната или зона)
struct HueGroup: Codable, Identifiable {
    /// Уникальный идентификатор группы
    var id: String = UUID().uuidString
    
    /// Тип ресурса
    var type: String = "grouped_light"
    
    /// Тип группы (room, zone, light_group, etc.)
    var group_type: String?
    
    /// Владелец группы
    var owner: ResourceIdentifier?
    
    /// Состояние включения группы
    var on: OnState?
    
    /// Настройки яркости группы
    var dimming: Dimming?
    
    /// Оповещения
    var alert: HueAlert?
    
    /// Метаданные группы
    var metadata: GroupMetadata?
}



/// Метаданные группы
struct GroupMetadata: Codable {
    /// Название группы
    var name: String?
    
    /// Архетип комнаты (для типа room)
    var archetype: String?
}

/// Состояние группы для обновления
struct GroupState: Codable {
    /// Включение/выключение
    var on: OnState?
    
    /// Яркость
    var dimming: Dimming?
    
    /// Оповещение
    var alert: HueAlert?
}

/// Оповещения
struct HueAlert: Codable {
    /// Список доступных действий
    var action_values: [String]?
}
