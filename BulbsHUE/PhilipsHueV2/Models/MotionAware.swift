//
//  MotionAware.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 05.09.2025.
//

import SwiftUI
import Foundation

/// НОВИНКА 2024: MotionAware API для Hue Bridge Pro
/// Обеспечивает интеллектуальное управление освещением на основе детекции движения
/// Только для совместимых устройств с Hue Bridge Pro
struct MotionAwareConfig: Codable, Identifiable {
    /// Уникальный идентификатор конфигурации
    var id: String = UUID().uuidString
    
    /// Тип ресурса
    var type: String = "motion_aware"
    
    /// Метаданные конфигурации
    var metadata: MotionAwareMetadata = MotionAwareMetadata()
    
    /// Включено ли MotionAware управление
    var enabled: Bool = false
    
    /// Чувствительность детекции движения (1-10)
    var sensitivity: Int = 5
    
    /// Зоны покрытия сенсора
    var coverage_zones: [MotionZone]?
    
    /// Временные периоды для различного поведения
    var time_periods: [TimePeriod]?
    
    /// Связанные лампы и группы
    var controlled_lights: [ResourceIdentifier]?
    
    /// Поведение освещения при детекции движения
    var motion_behavior: MotionBehavior?
    
    /// Поведение освещения при отсутствии движения
    var no_motion_behavior: NoMotionBehavior?
    
    /// Максимальная длительность включения без движения (секунды)
    var timeout_duration: Int = 600
}

/// Метаданные MotionAware конфигурации
struct MotionAwareMetadata: Codable {
    /// Название конфигурации
    var name: String = "Motion Aware"
    
    /// Описание
    var description: String?
}

/// Зона покрытия сенсора движения
struct MotionZone: Codable, Identifiable {
    /// Уникальный идентификатор зоны
    var id: String = UUID().uuidString
    
    /// Название зоны
    var name: String
    
    /// Геометрические параметры зоны (прямоугольная область)
    var geometry: ZoneGeometry
    
    /// Чувствительность в данной зоне (переопределяет общую)
    var sensitivity_override: Int?
    
    /// Минимальное время нахождения в зоне для срабатывания (миллисекунды)
    var dwell_time: Int = 100
}

/// Геометрические параметры зоны
struct ZoneGeometry: Codable {
    /// Координаты углов зоны (нормализованные 0.0-1.0)
    var corners: [GeometryPoint]
    
    /// Высота зоны над полом (метры, опционально)
    var height_min: Double?
    var height_max: Double?
}

/// Точка в геометрии зоны
struct GeometryPoint: Codable {
    /// X координата (0.0-1.0)
    var x: Double
    
    /// Y координата (0.0-1.0)
    var y: Double
}

/// Временной период с различным поведением
struct TimePeriod: Codable, Identifiable {
    /// Уникальный идентификатор периода
    var id: String = UUID().uuidString
    
    /// Название периода
    var name: String
    
    /// Время начала (формат HH:mm)
    var start_time: String
    
    /// Время окончания (формат HH:mm)
    var end_time: String
    
    /// Дни недели (1-7, где 1 = понедельник)
    var days_of_week: [Int] = [1, 2, 3, 4, 5, 6, 7]
    
    /// Переопределение поведения для этого периода
    var motion_behavior_override: MotionBehavior?
    var no_motion_behavior_override: NoMotionBehavior?
    
    /// Переопределение таймаута для этого периода
    var timeout_override: Int?
}

/// Поведение при детекции движения
struct MotionBehavior: Codable {
    /// Действие с освещением
    var action: MotionAction = .turn_on
    
    /// Яркость при включении (1-100)
    var brightness: Int = 80
    
    /// Цвет или цветовая температура
    var color_settings: ColorSettings?
    
    /// Время перехода к новому состоянию (миллисекунды)
    var transition_time: Int = 400
    
    /// Плавное увеличение яркости при входе
    var fade_in_duration: Int = 2000
}

/// Поведение при отсутствии движения
struct NoMotionBehavior: Codable {
    /// Действие с освещением
    var action: NoMotionAction = .turn_off
    
    /// Время перехода (миллисекунды)
    var transition_time: Int = 2000
    
    /// Плавное затухание перед выключением
    var fade_out_duration: Int = 5000
    
    /// Предупреждающее мигание перед выключением
    var warning_flash: Bool = false
}

/// Действие при детекции движения
enum MotionAction: String, Codable, CaseIterable {
    case turn_on = "turn_on"
    case increase_brightness = "increase_brightness" 
    case restore_previous = "restore_previous"
    case apply_scene = "apply_scene"
    case no_action = "no_action"
}

/// Действие при отсутствии движения
enum NoMotionAction: String, Codable, CaseIterable {
    case turn_off = "turn_off"
    case dim_to_level = "dim_to_level"
    case apply_scene = "apply_scene"
    case no_action = "no_action"
}

/// Цветовые настройки для MotionAware
struct ColorSettings: Codable {
    /// Цветовая температура в миредах
    var color_temperature: Int?
    
    /// XY цвет
    var color_xy: XYColor?
    
    /// ID сцены для применения
    var scene_id: String?
}

/// Статус MotionAware системы
struct MotionAwareStatus: Codable {
    /// Текущий статус
    var status: MotionAwareState = .idle
    
    /// Последнее обнаруженное движение
    var last_motion_detected: Date?
    
    /// Активная зона (если движение обнаружено)
    var active_zone_id: String?
    
    /// Оставшееся время до выключения (секунды)
    var timeout_remaining: Int?
    
    /// Активный временной период
    var active_time_period_id: String?
}

/// Состояние MotionAware системы
enum MotionAwareState: String, Codable, CaseIterable {
    case idle = "idle"                    // Ожидание движения
    case motion_detected = "motion_detected" // Движение обнаружено
    case lights_active = "lights_active"     // Освещение активировано
    case timeout_countdown = "timeout_countdown" // Обратный отсчет до выключения
    case fading_out = "fading_out"           // Плавное выключение
    case disabled = "disabled"               // Система отключена
}

// MARK: - Extensions

extension MotionAwareConfig {
    /// Проверяет, совместимо ли устройство с MotionAware
    static func isDeviceCompatible(product_data: ProductData?) -> Bool {
        guard let productData = product_data else { return false }
        
        // MotionAware требует Hue Bridge Pro или новее
        let compatibleModels = [
            "Hue Bridge Pro",
            "BSB002", // Bridge Pro model number
        ]
        
        return compatibleModels.contains(productData.model_id ?? "")
    }
    
    /// Валидирует конфигурацию MotionAware
    var isValid: Bool {
        return sensitivity >= 1 && sensitivity <= 10 &&
               timeout_duration >= 30 && timeout_duration <= 3600 &&
               !(controlled_lights?.isEmpty ?? true)
    }
}

extension TimePeriod {
    /// Проверяет, активен ли временной период в данный момент
    var isActive: Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now)
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // Конвертируем в формат 1-7 где 1 = понедельник
        let adjustedWeekday = currentWeekday == 1 ? 7 : currentWeekday - 1
        
        if !days_of_week.contains(adjustedWeekday) {
            return false
        }
        
        let currentTime = currentHour * 60 + currentMinute
        
        guard let startComponents = parseTime(start_time),
              let endComponents = parseTime(end_time) else {
            return false
        }
        
        let startMinutes = startComponents.hour * 60 + startComponents.minute
        let endMinutes = endComponents.hour * 60 + endComponents.minute
        
        if startMinutes <= endMinutes {
            // Период в пределах одного дня
            return currentTime >= startMinutes && currentTime <= endMinutes
        } else {
            // Период переходит через полночь
            return currentTime >= startMinutes || currentTime <= endMinutes
        }
    }
    
    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        return (hour: hour, minute: minute)
    }
}