//
//  Light.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// Модель лампы в системе Hue
/// Содержит всю информацию о физическом устройстве освещения
struct Light: Codable, Identifiable {
    /// Уникальный идентификатор лампы в формате UUID
    var id: String = UUID().uuidString
    
    /// Тип ресурса (всегда "light")
    var type: String = "light"
    
    /// Метаданные лампы
    var metadata: LightMetadata = LightMetadata()
    
    /// Текущее состояние включения/выключения
    var on: OnState = OnState()
    
    /// Настройки яркости (если поддерживается)
    var dimming: Dimming?
    
    /// Цветовые настройки (если поддерживается)
    var color: HueColor?
    
    /// Настройки цветовой температуры (если поддерживается)
    var color_temperature: ColorTemperature?
    
    /// Эффекты освещения (устаревшее)
    var effects: Effects?
    
    /// Динамические эффекты v2 (новые эффекты: Cosmos, Enchant, Sunbeam, Underwater)
    var effects_v2: EffectsV2?
    
    /// Режим работы лампы
    var mode: String?
    
    /// Возможности лампы
    var capabilities: Capabilities?
    
    /// Информация о цветовой гамме
    var color_gamut_type: String?
    var color_gamut: Gamut?
    
    /// Градиент (для поддерживающих устройств)
    var gradient: HueGradient?
}


/// Расширение для Light с поддержкой градиентов
extension Light {
    /// Проверяет, поддерживает ли лампа градиенты
    var supportsGradient: Bool {
        return gradient != nil
    }
    
    /// Количество точек градиента
    var gradientPointsCount: Int {
        return gradient?.points_capable ?? 0
    }
}

// Также добавьте поддержку идентификации новых ламп
extension Light {
    /// Проверяет, является ли лампа новой (не настроенной)
    var isNewLight: Bool {
        // Новые лампы обычно имеют стандартное имя типа "Hue light 1"
        return metadata.name.hasPrefix("Hue light") ||
               metadata.name.hasPrefix("Hue color lamp") ||
               metadata.name.hasPrefix("Hue white lamp")
    }
    /// Проверяет соответствие серийному номеру
    func matchesSerialNumber(_ serial: String) -> Bool {
        let cleanSerial = serial.uppercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        // Проверяем ID
        let cleanId = id.uppercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        if cleanId.contains(cleanSerial) {
            return true
        }
        
        // Проверяем имя
        if metadata.name.uppercased().contains(cleanSerial) {
            return true
        }
        
        // Проверяем последние 6 символов ID (часто это серийный номер)
        if cleanId.count >= 6 {
            let lastSix = String(cleanId.suffix(6))
            if lastSix == cleanSerial {
                return true
            }
        }
        
        return false
    }
}
/// Состояние лампы для обновления
struct LightState: Codable {
    /// Включение/выключение
    var on: OnState?
    
    /// Яркость
    var dimming: Dimming?
    
    /// Цвет
    var color: HueColor?
    
    /// Цветовая температура
    var color_temperature: ColorTemperature?
    
    /// Эффекты v2
    var effects_v2: EffectsV2?
    
    /// Динамика перехода (миллисекунды)
    var dynamics: Dynamics?
    
    /// Градиент
    var gradient: GradientState?
    
    /// Оповещение (для мигания)
    var alert: AlertState?
    
    /// Оптимизация: отправляйте только измененные параметры
    func optimizedState(currentLight: Light?) -> LightState {
        var optimized = self
        
        // Если лампа уже включена, не отправляем on:true
        if let current = currentLight, current.on.on, optimized.on?.on == true {
            optimized.on = nil
        }
        
        // Если яркость не изменилась, не отправляем
        if let current = currentLight,
           let currentBrightness = current.dimming?.brightness,
           let newBrightness = optimized.dimming?.brightness,
           abs(currentBrightness - newBrightness) < 1 {
            optimized.dimming = nil
        }
        
        return optimized
    }
}



/// Метаданные лампы
struct LightMetadata: Codable {
    /// Пользовательское имя лампы
    var name: String = "Новая лампа"
    
    /// Архетип лампы (тип установки)
    var archetype: String?
}

/// Настройки динамики перехода
struct Dynamics: Codable {
    /// Длительность перехода в миллисекундах
    var duration: Int?
}


/// Эффекты освещения (v1 - устаревшее)
struct Effects: Codable {
    /// Текущий эффект
    var effect: String?
    
    /// Список доступных эффектов
    var effect_values: [String]?
    
    /// Статус эффекта
    var status: String?
}

/// Расширенные эффекты (v2)
struct EffectsV2: Codable {
    /// Текущий эффект
    var effect: String?
    
    /// Список доступных эффектов
    /// Новые эффекты: "cosmos", "enchant", "sunbeam", "underwater"
    /// Дополнительные: "candle", "fireplace", "prism", "glisten", "opal", "sparkle"
    var effect_values: [String]?
    
    /// Статус эффекта (теперь объект)
    var status: EffectStatus?
    
    /// Действие эффекта
    var action: EffectAction?
    
    /// Длительность эффекта в миллисекундах
    var duration: Int?
}

/// Статус эффекта v2
struct EffectStatus: Codable {
    /// Текущий эффект
    var effect: String?
    
    /// Доступные эффекты
    var effect_values: [String]?
}


/// Действие эффекта v2
struct EffectAction: Codable {
    /// Доступные эффекты для действия
    var effect_values: [String]?
}



/// Градиентная конфигурация
struct HueGradient: Codable {
    /// Точки градиента
    var points: [GradientPoint]?
    
    /// Максимальное количество точек
    var points_capable: Int?
    
    /// Режим градиента
    var mode: String?
    
    /// Режим пикселей (для развлечений)
    var pixel_count: Int?
}

/// Точка градиента
struct GradientPoint: Codable {
    /// Цвет точки
    var color: HueColor?
    
    /// Позиция точки (0.0-1.0)
    var position: Double?
}

/// Состояние градиента для обновления
struct GradientState: Codable {
    /// Точки градиента
    var points: [GradientPoint]?
    
    /// Режим градиента
    var mode: String?
}


/// Возможности устройства
struct Capabilities: Codable {
    /// Сертифицировано для развлечений
    var certified: Bool?
    
    /// Поддержка потоковой передачи
    var streaming: StreamingCapabilities?
}

/// Возможности потоковой передачи
struct StreamingCapabilities: Codable {
    /// Поддержка рендеринга
    var renderer: Bool?
    
    /// Поддержка прокси
    var proxy: Bool?
}


/// Настройки цветовой температуры
struct ColorTemperature: Codable {
    /// Значение в миредах (153-500)
    var mirek: Int?
    
    /// Допустимый диапазон
    var mirek_schema: MirekSchema?
}

/// Схема диапазона цветовой температуры
struct MirekSchema: Codable {
    /// Минимальное значение
    var mirek_minimum: Int?
    
    /// Максимальное значение
    var mirek_maximum: Int?
}



/// Цветовые настройки
struct HueColor: Codable {
    /// XY координаты цвета в цветовом пространстве CIE
    var xy: XYColor?
    
    /// Цветовая гамма устройства (устаревшее, используйте color_gamut_type в Light)
    var gamut: Gamut?
    
    /// Тип цветовой гаммы
    var gamut_type: String?
}


/// Настройки яркости
struct Dimming: Codable {
    /// Уровень яркости (1-100)
    var brightness: Double = 100.0
    
    /// Минимальный уровень затемнения
    var min_dim_level: Double?
}


/// Состояние включения/выключения
struct OnState: Codable {
    /// Флаг включения
    var on: Bool = false
}

/// Состояние оповещения (для мигания лампы)
struct AlertState: Codable {
    /// Действие оповещения
    /// - "breathe": мигание лампы для визуального подтверждения
    /// - "none": отключить оповещение
    var action: String
    
    /// Инициализация с действием
    /// - Parameter action: Тип действия оповещения
    init(action: String) {
        self.action = action
    }
}

