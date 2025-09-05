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
    
    /// Статус связи с устройством (не из API, устанавливается локально)
    var communicationStatus: CommunicationStatus
    
    /// Последние ошибки связи (не из API, устанавливается локально)
    var lastErrors: [String]
    
    /// Пользовательские CodingKeys для исключения локальных полей из декодирования
    enum CodingKeys: String, CodingKey {
        case id, type, metadata, on, dimming, color, color_temperature
        case effects, effects_v2, mode, capabilities, color_gamut_type, color_gamut, gradient
        // communicationStatus и lastErrors не включены - они не декодируются из JSON
    }
    
    /// Инициализатор по умолчанию
    init() {
        self.id = UUID().uuidString
        self.type = "light"
        self.metadata = LightMetadata()
        self.on = OnState()
        self.dimming = nil
        self.color = nil
        self.color_temperature = nil
        self.effects = nil
        self.effects_v2 = nil
        self.mode = nil
        self.capabilities = nil
        self.color_gamut_type = nil
        self.color_gamut = nil
        self.gradient = nil
        self.communicationStatus = .unknown
        self.lastErrors = []
    }
    
    /// Удобный инициализатор с параметрами
    init(id: String? = nil,
         type: String = "light",
         metadata: LightMetadata = LightMetadata(),
         on: OnState = OnState(),
         dimming: Dimming? = nil,
         color: HueColor? = nil,
         color_temperature: ColorTemperature? = nil,
         effects: Effects? = nil,
         effects_v2: EffectsV2? = nil,
         mode: String? = nil,
         capabilities: Capabilities? = nil,
         color_gamut_type: String? = nil,
         color_gamut: Gamut? = nil,
         gradient: HueGradient? = nil) {
        self.id = id ?? UUID().uuidString
        self.type = type
        self.metadata = metadata
        self.on = on
        self.dimming = dimming
        self.color = color
        self.color_temperature = color_temperature
        self.effects = effects
        self.effects_v2 = effects_v2
        self.mode = mode
        self.capabilities = capabilities
        self.color_gamut_type = color_gamut_type
        self.color_gamut = color_gamut
        self.gradient = gradient
        self.communicationStatus = .unknown
        self.lastErrors = []
    }
    
    /// Инициализатор из декодера с установкой значений по умолчанию для локальных полей
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "light"
        metadata = try container.decodeIfPresent(LightMetadata.self, forKey: .metadata) ?? LightMetadata()
        on = try container.decodeIfPresent(OnState.self, forKey: .on) ?? OnState()
        dimming = try container.decodeIfPresent(Dimming.self, forKey: .dimming)
        color = try container.decodeIfPresent(HueColor.self, forKey: .color)
        color_temperature = try container.decodeIfPresent(ColorTemperature.self, forKey: .color_temperature)
        effects = try container.decodeIfPresent(Effects.self, forKey: .effects)
        effects_v2 = try container.decodeIfPresent(EffectsV2.self, forKey: .effects_v2)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        capabilities = try container.decodeIfPresent(Capabilities.self, forKey: .capabilities)
        color_gamut_type = try container.decodeIfPresent(String.self, forKey: .color_gamut_type)
        color_gamut = try container.decodeIfPresent(Gamut.self, forKey: .color_gamut)
        gradient = try container.decodeIfPresent(HueGradient.self, forKey: .gradient)
        
        // Локальные поля устанавливаются по умолчанию
        self.communicationStatus = .unknown
        self.lastErrors = []
    }
    
    /// Кодирование - исключаем локальные поля
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(on, forKey: .on)
        try container.encodeIfPresent(dimming, forKey: .dimming)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(color_temperature, forKey: .color_temperature)
        try container.encodeIfPresent(effects, forKey: .effects)
        try container.encodeIfPresent(effects_v2, forKey: .effects_v2)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(capabilities, forKey: .capabilities)
        try container.encodeIfPresent(color_gamut_type, forKey: .color_gamut_type)
        try container.encodeIfPresent(color_gamut, forKey: .color_gamut)
        try container.encodeIfPresent(gradient, forKey: .gradient)
        // communicationStatus и lastErrors не кодируются
    }
}

/// Статус связи с лампой
enum CommunicationStatus: String, Codable {
    case online = "online"           // Устройство отвечает нормально
    case offline = "offline"         // Устройство не отвечает (выключено из сети)
    case issues = "issues"           // Есть проблемы связи, но устройство частично отвечает
    case unknown = "unknown"         // Статус неизвестен
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
    
    /// Проверяет реальную доступность лампы (учитывая статус связи)
    var isReachable: Bool {
        return communicationStatus == .online
    }
    
    /// Проверяет есть ли проблемы со связью
    var hasCommunicationIssues: Bool {
        return communicationStatus == .issues || communicationStatus == .offline
    }
    
    /// Возвращает отображаемое состояние лампы (учитывая связь)
    var effectiveState: OnState {
        if !isReachable {
            // Если лампа недоступна, показываем как выключенную
            return OnState(on: false)
        }
        return on
    }
    
    /// Возвращает реальное состояние лампы для ViewModel (с яркостью)
    var effectiveBrightness: Double {
        if !isReachable {
            return 0.0
        }
        return dimming?.brightness ?? 0.0
    }
    
    /// Возвращает состояние лампы в формате ожидаемом ViewModel
    var effectiveStateWithBrightness: (isOn: Bool, brightness: Double) {
        if !isReachable {
            return (isOn: false, brightness: 0.0)
        }
        return (isOn: on.on, brightness: dimming?.brightness ?? 0.0)
    }
}

// Также добавьте поддержку идентификации новых ламп
extension Light {
    /// Проверяет, является ли лампа новой (не настроенной)
    /// УПРОЩЕННЫЙ подход: не полагаемся на имена, используем только базовые индикаторы
    var isNewLight: Bool {
        // В новом API-flow полагаемся на сравнение списков до/после поиска
        // Но сохраняем минимальную эвристику для обратной совместимости
        
        let lowercaseName = metadata.name.lowercased()
        
        // Простая проверка стандартных префиксов Philips Hue
        let isStandardHueName = lowercaseName.hasPrefix("hue") || 
                                lowercaseName.contains("dimmable") ||
                                lowercaseName.contains("color light") ||
                                lowercaseName.contains("extended color")
        
        // Проверка числового суффикса (Light 1, Lamp 23)
        let hasNumericSuffix = metadata.name.range(of: #"\s+\d+$"#, options: .regularExpression) != nil
        
        // НЕ содержит указания на кастомизацию (названия комнат)
        let hasNoCustomization = !lowercaseName.contains("kitchen") &&
                                 !lowercaseName.contains("bedroom") &&
                                 !lowercaseName.contains("living") &&
                                 !lowercaseName.contains("bathroom") &&
                                 !lowercaseName.contains("office")
        
        return (isStandardHueName || hasNumericSuffix) && hasNoCustomization
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
    
    /// Архетип лампы (тип установки или пользовательский подтип)
    var archetype: String?
    
    /// Название пользовательского подтипа (наш UI-выбор, не из API)
    var userSubtypeName: String?
    
    /// Иконка пользовательского подтипа (не из API, локальное поле)
    var userSubtypeIcon: String?
    
    /// Пользовательские CodingKeys для исключения локального поля из декодирования
    enum CodingKeys: String, CodingKey {
        case name, archetype
        // userSubtypeIcon не включена - она не декодируется из JSON
    }
    
    /// Инициализатор с параметрами
    init(name: String = "Новая лампа", archetype: String? = nil, userSubtypeName: String? = nil, userSubtypeIcon: String? = nil) {
        self.name = name
        self.archetype = archetype
        self.userSubtypeName = userSubtypeName
        self.userSubtypeIcon = userSubtypeIcon
    }
    
    /// Инициализатор из декодера с установкой значений по умолчанию для локальных полей
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Новая лампа"
        archetype = try container.decodeIfPresent(String.self, forKey: .archetype)
        
        // Локальное поле устанавливается по умолчанию
        self.userSubtypeName = nil
        self.userSubtypeIcon = nil
    }
    
    /// Кодирование - исключаем локальные поля
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(archetype, forKey: .archetype)
        // userSubtypeIcon не кодируется
    }
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
    /// Обновлено 2024: добавлены "cosmos", "enchant", "sunbeam", "underwater"
    /// Базовые: "candle", "fireplace", "prism", "glisten", "opal", "sparkle" 
    /// Классические: "colorloop", "sunrise"
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

// MARK: - Equatable Conformance

extension Light: Equatable {
    /// Сравнение ламп по уникальному идентификатору
    /// Две лампы считаются равными, если у них одинаковый id
    static func == (lhs: Light, rhs: Light) -> Bool {
        return lhs.id == rhs.id
    }
}

