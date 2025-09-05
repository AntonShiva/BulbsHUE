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

// MARK: - Hue API v1 Response Models

/// Ответ Hue Bridge API v1 (для поиска ламп и других операций)
struct HueAPIResponse: Codable {
    let success: [String: String]?
    let error: HueAPIErrorResponse?
    
    private enum CodingKeys: String, CodingKey {
        case success, error
    }
}

/// Ошибка в ответе Hue API v1
struct HueAPIErrorResponse: Codable {
    let type: Int
    let address: String
    let description: String
}

/// Ответ с новыми лампами (API v1)
struct NewLightsResponse: Codable {
    let lastscan: String
    private let lightsDictionary: [String: LightV1Data]
    
    var lights: [Light] {
        return lightsDictionary.compactMap { (id, lightData) in
            // Преобразуем данные API v1 в нашу модель Light
            return Light(
                id: id,
                type: "light",
                metadata: LightMetadata(
                    name: lightData.name,
                    archetype: "unknown"
                ),
                on: OnState(on: lightData.state.on),
                dimming: Dimming(brightness: Double(lightData.state.bri)),
                color: HueColor(
                    xy: XYColor(x: lightData.state.xy[0], y: lightData.state.xy[1]),
                    gamut: Gamut(
                        red: XYColor(x: 0.7, y: 0.3),
                        green: XYColor(x: 0.17, y: 0.7),
                        blue: XYColor(x: 0.15, y: 0.06)
                    ),
                    gamut_type: "C"
                )
            )
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case lastscan
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.lastscan = try container.decode(String.self, forKey: .lastscan)
        
        // Все остальные ключи - это ID ламп с их данными
        var lightsDict: [String: LightV1Data] = [:]
        let dynamicContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        
        for key in dynamicContainer.allKeys {
            if key.stringValue != "lastscan" {
                if let lightData = try? dynamicContainer.decode(LightV1Data.self, forKey: key) {
                    lightsDict[key.stringValue] = lightData
                }
            }
        }
        
        self.lightsDictionary = lightsDict
    }
}

/// Данные лампы в формате API v1
struct LightV1Data: Codable {
    let name: String
    let type: String
    let modelid: String
    let state: LightV1State
    let uniqueid: String?  // Это может содержать MAC адрес/серийный номер
    let manufacturername: String?
    let swversion: String?
    
    enum CodingKeys: String, CodingKey {
        case name, type, modelid, state, uniqueid, manufacturername, swversion
    }
}

/// Состояние лампы в формате API v1
struct LightV1State: Codable {
    let on: Bool
    let bri: Int
    let xy: [Double]
}

/// Вспомогательная структура для динамического декодирования JSON ключей
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Device Details Response для получения серийных номеров
struct DeviceDetailsResponse: Codable {
    let data: [DeviceDetails]
}

struct DeviceDetails: Codable {
    let id: String
    let metadata: DeviceMetadata
    let productData: ProductData?
    
    enum CodingKeys: String, CodingKey {
        case id, metadata
        case productData = "product_data"
    }
}

struct DeviceMetadata: Codable {
    let name: String
}

// ProductData уже определен в Common.swift

// MARK: - Generic Response Wrapper для API v2

/// Универсальная обертка для ответов Hue API v2
struct HueResponse<T: Codable>: Codable {
    let data: T
    let errors: [APIError]?
    
    init(data: T, errors: [APIError]? = nil) {
        self.data = data
        self.errors = errors
    }
}
