//
//  SensorEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - Domain Entity для сенсора
/// Чистая доменная модель сенсора без зависимостей от API
struct SensorEntity: Equatable, Identifiable {
    let id: String
    let name: String
    let type: SensorType
    let isPresent: Bool?
    let lightLevel: Int?
    let temperature: Double?
    let lastUpdated: Date?
    let batteryLevel: Int?
    let isReachable: Bool
    
    enum SensorType: String, CaseIterable {
        case motion = "motion"
        case lightLevel = "light_level"
        case temperature = "temperature"
        case button = "button"
        case rotarySwitch = "rotary_switch"
        case contactSensor = "contact"
        case tamper = "tamper"
        
        var displayName: String {
            switch self {
            case .motion: return "Motion Sensor"
            case .lightLevel: return "Light Level Sensor"
            case .temperature: return "Temperature Sensor"
            case .button: return "Button"
            case .rotarySwitch: return "Rotary Switch"
            case .contactSensor: return "Contact Sensor"
            case .tamper: return "Tamper Sensor"
            }
        }
    }
    
    /// Инициализатор для создания новой сущности
    init(id: String, 
         name: String, 
         type: SensorType, 
         isPresent: Bool? = nil, 
         lightLevel: Int? = nil, 
         temperature: Double? = nil, 
         lastUpdated: Date? = nil, 
         batteryLevel: Int? = nil, 
         isReachable: Bool = true) {
        self.id = id
        self.name = name
        self.type = type
        self.isPresent = isPresent
        self.lightLevel = lightLevel
        self.temperature = temperature
        self.lastUpdated = lastUpdated
        self.batteryLevel = batteryLevel
        self.isReachable = isReachable
    }
}
