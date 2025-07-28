//
//  ResponseWrappers.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// Обертка для списка ламп
struct LightsResponse: Codable {
    var data: [Light]
}

/// Обертка для одной лампы
struct LightResponse: Codable {
    var data: [Light]
}

/// Обертка для списка сцен
struct ScenesResponse: Codable {
    var data: [HueScene]
}

/// Обертка для одной сцены
struct SceneResponse: Codable {
    var data: [HueScene]
}

/// Обертка для списка групп
struct GroupsResponse: Codable {
    var data: [HueGroup]
}

/// Обертка для списка сенсоров
struct SensorsResponse: Codable {
    var data: [HueSensor]
}

/// Обертка для одного сенсора
struct SensorResponse: Codable {
    var data: [HueSensor]
}

/// Обертка для списка правил
struct RulesResponse: Codable {
    var data: [HueRule]
}

/// Обертка для одного правила
struct RuleResponse: Codable {
    var data: [HueRule]
}

/// Общий ответ без данных
struct GenericResponse: Codable {
    var errors: [APIError]?
}

/// Ошибка API
struct APIError: Codable {
    var description: String?
}
