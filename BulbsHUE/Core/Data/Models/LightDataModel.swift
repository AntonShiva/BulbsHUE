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
    
    /// Тип архетипа лампы (название подтипа: "DESK LAMP", "CEILING ROUND", etc.)
    var archetype: String
    
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
        archetype: String,
        isOn: Bool = false,
        brightness: Double = 50.0,
        colorTemperature: Int? = nil,
        colorX: Double? = nil,
        colorY: Double? = nil,
        isAssignedToEnvironment: Bool = false
    ) {
        self.lightId = lightId
        self.name = name
        self.archetype = archetype
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
            archetype: light.metadata.archetype ?? "other",
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
            archetype: archetype
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
        print("🔄 LightDataModel.updateFromLight:")
        print("   └── Текущий archetype в БД: '\(self.archetype)'")
        print("   └── Новый archetype из API: '\(light.metadata.archetype ?? "nil")'")
        
        self.name = light.metadata.name
        
        // ВАЖНО: НЕ затирать пользовательский выбор подтипа из UI данными из API!
        // Если в локальном хранилище уже есть подтип из наших BulbTypeModels (пользовательский выбор),
        // НИКОГДА не заменяем его на archetype из API Philips Hue (например, sultan_bulb)
        
        let ourSubtypes = [
            // TABLE
            "TRADITIONAL LAMP", "DESK LAMP", "TABLE WASH",
            // FLOOR  
            "CHRISTMAS TREE", "FLOOR SHADE", "FLOOR LANTERN", "BOLLARD", "GROUND SPOT", "RECESSED FLOOR", "LIGHT BAR",
            // WALL
            "WALL LANTERN", "WALL SHADE", "WALL SPOT", "DUAL WALL LIGHT",
            // CEILING
            "PENDANT ROUND", "PENDANT HORIZONTAL", "CEILING ROUND", "CEILING SQUARE", "SINGLE SPOT", "DOUBLE SPOT", "RECESSED CEILING", "PEDANT SPOT", "CEILING HORIZONTAL", "CEILING TUBE",
            // OTHER
            "SIGNATURE BULB", "ROUNDED BULB", "SPOT", "FLOOD LIGHT", "CANDELABRA BULB", "FILAMENT BULB", "MINI-BULB", "HUE LIGHTSTRIP", "LIGHTGUIDE", "PLAY LIGHT BAR", "HUE BLOOM", "HUE IRIS", "SMART PLUG", "HUE CENTRIS", "HUE TUBE", "HUE SIGNE", "FLOODLIGHT CAMERA", "TWILIGHT"
        ]
        
        // Если текущий archetype - это пользовательский выбор, НЕ перезаписываем его
        if ourSubtypes.contains(self.archetype.uppercased()) {
            print("   └── Сохраняем пользовательский подтип: '\(self.archetype)' (НЕ перезаписываем на '\(light.metadata.archetype ?? "nil")')")
        } else if self.archetype.isEmpty,
                  let newArchetype = light.metadata.archetype,
                  !newArchetype.isEmpty {
            print("   └── Устанавливаем archetype из API: '\(newArchetype)'")
            self.archetype = newArchetype
        } else {
            print("   └── Не изменяем archetype")
        }
        
        self.isOn = light.on.on
        self.brightness = light.dimming?.brightness ?? self.brightness
        self.colorTemperature = light.color_temperature?.mirek
        self.colorX = light.color?.xy?.x
        self.colorY = light.color?.xy?.y
        self.lastUpdated = Date()
    }
}
