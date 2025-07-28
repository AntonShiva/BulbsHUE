//
//  Sensor.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Foundation

/// Модель сенсора (движения, освещенности, температуры, кнопки)
struct HueSensor: Codable, Identifiable {
    /// Уникальный идентификатор
    var id: String = UUID().uuidString
    
    /// Тип ресурса
    var type: String = "device"
    
    /// Метаданные
    var metadata: SensorMetadata = SensorMetadata()
    
    /// Сервисы устройства
    var services: [ResourceIdentifier]?
    
    /// Тип продукта
    var product_data: ProductData?
}

/// Метаданные сенсора
struct SensorMetadata: Codable {
    /// Название
    var name: String = "Сенсор"
    
    /// Архетип
    var archetype: String?
}

/// Состояние датчика движения
struct MotionSensorState: Codable {
    /// Обнаружено движение
    var motion: MotionState?
    
    /// Включен ли сенсор
    var enabled: Bool?
}

/// Состояние движения
struct MotionState: Codable {
    /// Движение обнаружено
    var motion: Bool = false
    
    /// Валидность данных движения
    var motion_valid: Bool = true
}

/// События кнопок (для Hue Tap, Dimmer Switch и др.)
enum ButtonEvent: Int, Codable {
    // Hue Tap button events
    case tapButton1 = 34
    case tapButton2 = 16
    case tapButton3 = 17
    case tapButton4 = 18
    
    // Hue Dimmer Switch events
    // Button 1 (ON)
    case dimmerOnInitialPress = 1000
    case dimmerOnHold = 1001
    case dimmerOnShortRelease = 1002
    case dimmerOnLongRelease = 1003
    
    // Button 2 (DIM UP)
    case dimmerUpInitialPress = 2000
    case dimmerUpHold = 2001
    case dimmerUpShortRelease = 2002
    case dimmerUpLongRelease = 2003
    
    // Button 3 (DIM DOWN)
    case dimmerDownInitialPress = 3000
    case dimmerDownHold = 3001
    case dimmerDownShortRelease = 3002
    case dimmerDownLongRelease = 3003
    
    // Button 4 (OFF)
    case dimmerOffInitialPress = 4000
    case dimmerOffHold = 4001
    case dimmerOffShortRelease = 4002
    case dimmerOffLongRelease = 4003
}

/// Состояние кнопки
struct ButtonState: Codable {
    /// Событие кнопки
    var button_report: ButtonReport?
    
    /// Последнее событие
    var last_event: String?
}

/// Отчет о нажатии кнопки
struct ButtonReport: Codable {
    /// Событие
    var event: String?
    
    /// Время обновления
    var updated: Date?
}

/// Состояние датчика освещенности
struct LightLevelSensorState: Codable {
    /// Уровень освещенности в люксах (вычисляется как 10^(lightlevel/10000))
    var lightlevel: Int?
    
    /// Валидность данных
    var lightlevel_valid: Bool?
    
    /// Флаг темноты (lightlevel < darktreshold)
    var dark: Bool?
    
    /// Флаг дневного света (lightlevel > daylighttreshold)
    var daylight: Bool?
    
    /// Вычисленное значение в люксах
    var lux: Double? {
        guard let level = lightlevel else { return nil }
        return pow(10, Double(level) / 10000.0)
    }
}

/// Состояние датчика температуры
struct TemperatureSensorState: Codable {
    /// Температура в сотых долях градуса Цельсия
    var temperature: Int?
    
    /// Валидность данных
    var temperature_valid: Bool?
    
    /// Температура в градусах Цельсия
    var celsius: Double? {
        guard let temp = temperature else { return nil }
        return Double(temp) / 100.0
    }
    
    /// Температура в градусах Фаренгейта
    var fahrenheit: Double? {
        guard let c = celsius else { return nil }
        return c * 9/5 + 32
    }
}
