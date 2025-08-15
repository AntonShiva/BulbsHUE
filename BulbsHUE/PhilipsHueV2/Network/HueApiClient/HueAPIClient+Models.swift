//
//  HueAPIClient+Models.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import Foundation

// MARK: - Модели данных для API v2

/// Ответ API v2 для устройств
struct V2DevicesResponse: Codable {
    let data: [V2Device]
}

/// Устройство в API v2
struct V2Device: Codable {
    let id: String
    let id_v1: String?
    let serial_number: String?
    let metadata: V2Metadata?
    let services: [V2Service]
}

/// Метаданные устройства
struct V2Metadata: Codable {
    let name: String?
    let archetype: String?
}

/// Сервис устройства
struct V2Service: Codable {
    let rid: String
    let rtype: String
}

/// Ответ API v2 для Zigbee connectivity
struct V2ZigbeeResponse: Codable {
    let data: [V2ZigbeeConn]
}

/// Zigbee connectivity в API v2
struct V2ZigbeeConn: Codable {
    struct Owner: Codable {
        let rid: String
        let rtype: String
    }
    
    let id: String
    let owner: Owner
    let mac_address: String?
    let mac: String?
}

// MARK: - Модели данных для API v1

/// Лампа в API v1
struct V1Light: Codable {
    let name: String
    let uniqueid: String?
    let state: V1LightState
}

/// Состояние лампы в API v1
struct V1LightState: Codable {
    let on: Bool
    let bri: Int?
}



/// Состояние лампы v1 для поиска
struct LightV1StateData: Codable {
    let on: Bool?
    let bri: Int?
    let hue: Int?
    let sat: Int?
    let reachable: Bool?
}



/// Ошибка в batch операции
struct BatchError: Codable {
    let description: String
}

/// Результат batch операции
struct BatchResult: Codable {
    let id: String
    let status: String
}





/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+Models.swift
 
 Описание:
 Содержит все модели данных для работы с Philips Hue API v1 и v2.
 
 Основные категории:
 - Модели API v2 (V2Device, V2ZigbeeConn и т.д.)
 - Модели API v1 (V1Light, LightV1Data и т.д.)
 - Response модели (GenericResponse, BatchResponse и т.д.)
 - Entertainment Configuration модели
 - Структуры для различных endpoints
 - Placeholder модели (должны быть заменены реальными)
 
 Зависимости:
 - Foundation для Codable
 
 Связанные файлы:
 - Все расширения HueAPIClient используют эти модели
 */

