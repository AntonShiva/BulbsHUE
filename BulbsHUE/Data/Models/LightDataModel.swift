//
//  LightDataModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/11/25.
//

import Foundation
import SwiftData

/// SwiftData модель для персистентного хранения данных ламп
/// Конвертируется в Light модель для использования в UI
@Model
final class LightDataModel {
    
    // MARK: - Stored Properties
    
    /// Уникальный идентификатор лампы
    var lightId: String
    
    /// Название лампы
    var name: String
    
    /// Пользовательский подтип лампы (название подтипа: "DESK LAMP", "CEILING ROUND", etc.)
    var userSubtype: String
    
    /// Иконка пользовательского подтипа (например: "t2", "c3", "o1", etc.)
    var userSubtypeIcon: String
    
    /// Архетип из Philips Hue API (техническая информация: "sultan_bulb", "classic_bulb", etc.)
    var apiArchetype: String?
    
    /// Состояние включения лампы
    var isOn: Bool
    
    /// Яркость лампы (0.0 - 100.0)
    var brightness: Double
    
    /// Цветовая температура (153 - 500 mired)
    var colorTemperature: Int?
    
    /// Цвет лампы в формате XY координат
    var colorX: Double?
    var colorY: Double?
    
    /// Назначена ли лампа в Environment (видна в списке)
    var isAssignedToEnvironment: Bool
    
    /// Дата последнего обновления данных
    var lastUpdated: Date
    
    // MARK: - Initialization
    
    /// Инициализация модели данных
    /// - Parameters:
    ///   - lightId: ID лампы
    ///   - name: Название лампы
    ///   - archetype: Тип лампы
    ///   - isOn: Состояние включения
    ///   - brightness: Яркость
    ///   - colorTemperature: Цветовая температура
    ///   - colorX: X координата цвета
    ///   - colorY: Y координата цвета
    ///   - isAssignedToEnvironment: Назначена ли в Environment
    init(
        lightId: String,
        name: String,
        userSubtype: String,
        userSubtypeIcon: String,
        apiArchetype: String? = nil,
        isOn: Bool = false,
        brightness: Double = 50.0,
        colorTemperature: Int? = nil,
        colorX: Double? = nil,
        colorY: Double? = nil,
        isAssignedToEnvironment: Bool = false
    ) {
        self.lightId = lightId
        self.name = name
        self.userSubtype = userSubtype
        self.userSubtypeIcon = userSubtypeIcon
        self.apiArchetype = apiArchetype
        self.isOn = isOn
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.colorX = colorX
        self.colorY = colorY
        self.isAssignedToEnvironment = isAssignedToEnvironment
        self.lastUpdated = Date()
    }
}

// MARK: - Light Model Conversion

extension LightDataModel {
    
    /// Создать LightDataModel из Light модели
    /// - Parameters:
    ///   - light: Light модель из API
    ///   - isAssignedToEnvironment: Назначена ли в Environment
    /// - Returns: LightDataModel для сохранения
    static func fromLight(_ light: Light, isAssignedToEnvironment: Bool = false) -> LightDataModel {
        return LightDataModel(
            lightId: light.id,
            name: light.metadata.name,
            userSubtype: "Smart Light", // ← Дефолтный подтип (пользователь выберет свой)
            userSubtypeIcon: "o2", // ← Дефолтная иконка "rounded bulb"
            apiArchetype: light.metadata.archetype, // ← Сохраняем API данные отдельно
            isOn: light.on.on,
            brightness: light.dimming?.brightness ?? 50.0,
            colorTemperature: light.color_temperature?.mirek,
            colorX: light.color?.xy?.x,
            colorY: light.color?.xy?.y,
            isAssignedToEnvironment: isAssignedToEnvironment
        )
    }
    
    /// Конвертировать в Light модель для использования в UI
    /// - Returns: Light модель
    func toLight() -> Light {
        // Создаем компоненты Light модели
        let on = OnState(on: isOn)
        
        let dimming = Dimming(brightness: brightness)
        
        let colorTemperatureComponent: ColorTemperature? = {
            if let temp = colorTemperature {
                return ColorTemperature(mirek: temp)
            }
            return nil
        }()
        
        let colorComponent: HueColor? = {
            if let x = colorX, let y = colorY {
                return HueColor(xy: XYColor(x: x, y: y))
            }
            return nil
        }()
        
        let metadata = LightMetadata(
            name: name,
            archetype: apiArchetype,  // ← Сохраняем технический архетип как есть
            userSubtypeName: userSubtype, // ← Пользовательский подтип отдельно
            userSubtypeIcon: userSubtypeIcon  // ← Иконка пользовательского подтипа
        )
        
        return Light(
            id: lightId,
            metadata: metadata,
            on: on,
            dimming: dimming,
            color: colorComponent,
            color_temperature: colorTemperatureComponent
        )
    }
    
    /// Обновить данные из Light модели
    /// - Parameter light: Light модель из API
    func updateFromLight(_ light: Light) {
        self.name = light.metadata.name
        
        // ✅ НОВАЯ ЛОГИКА: Полностью разделяем пользовательский выбор и API данные
        
        // 1. Всегда обновляем API архетип (техническая информация)
        self.apiArchetype = light.metadata.archetype
        
        // 2. userSubtype и userSubtypeIcon берём из локальных полей Light, если они присутствуют
        if let localUserSubtype = light.metadata.userSubtypeName, !localUserSubtype.isEmpty {
            self.userSubtype = localUserSubtype
        }
        if let localUserIcon = light.metadata.userSubtypeIcon, !localUserIcon.isEmpty {
            self.userSubtypeIcon = localUserIcon
        }
        
        self.isOn = light.on.on
        self.brightness = light.dimming?.brightness ?? self.brightness
        self.colorTemperature = light.color_temperature?.mirek
        self.colorX = light.color?.xy?.x
        self.colorY = light.color?.xy?.y
        self.lastUpdated = Date()
    }
    
    /// Конвертирует API архетип в пользовательские данные (название + иконка)
    private func convertApiArchetypeToUserData(_ apiArchetype: String) -> (subtype: String, icon: String) {
        switch apiArchetype.lowercased() {
        case "sultan_bulb":
            return ("SIGNATURE BULB", "o1")
        case "classic_bulb":
            return ("ROUNDED BULB", "o2")
        case "vintage_bulb", "edison_bulb":
            return ("FILAMENT BULB", "o6")
        case "globe_bulb":
            return ("ROUNDED BULB", "o2")
        case "candle_bulb":
            return ("CANDELABRA BULB", "o5")
        default:
            return ("Smart Light", "o2")
        }
    }
}
