//
//  LightControlService.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import Foundation
import Combine

/// Сервис для управления лампами и предоставления информации о них
/// Реализует протоколы согласно принципу Dependency Inversion
/// Служит адаптером между AppViewModel и ItemControlViewModel
class LightControlService: ObservableObject, LightControlling {
    // MARK: - Private Properties
    
    /// Ссылка на основной AppViewModel
    private weak var appViewModel: AppViewModel?
    
    // MARK: - Initialization
    
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }
    
    // MARK: - LightsManaging Implementation
    
    var lights: [Light] {
        return appViewModel?.lightsViewModel.lights ?? []
    }
    
    var lightsPublisher: AnyPublisher<[Light], Never> {
        guard let appViewModel = appViewModel else {
            return Just([]).eraseToAnyPublisher()
        }
        return appViewModel.lightsViewModel.$lights.eraseToAnyPublisher()
    }
    
    func setPower(for light: Light, on: Bool) {
        appViewModel?.lightsViewModel.setPower(for: light, on: on)
    }
    
    func setBrightness(for light: Light, brightness: Double) {
        appViewModel?.lightsViewModel.setBrightness(for: light, brightness: brightness)
    }
    
    func commitBrightness(for light: Light, brightness: Double) {
        appViewModel?.lightsViewModel.commitBrightness(for: light, brightness: brightness)
    }
    
    // MARK: - GroupsProviding Implementation
    
    var groups: [HueGroup] {
        return appViewModel?.groupsViewModel.groups ?? []
    }
    
    var groupsPublisher: AnyPublisher<[HueGroup], Never> {
        guard let appViewModel = appViewModel else {
            return Just([]).eraseToAnyPublisher()
        }
        return appViewModel.groupsViewModel.$groups.eraseToAnyPublisher()
    }
    
    func findGroup(by id: String) -> HueGroup? {
        return groups.first { $0.id == id }
    }
    
    // MARK: - LightDisplaying Implementation
    
    func getRoomName(for light: Light) -> String {
        print("🏠 getRoomName для лампы '\(light.metadata.name)' (ID: \(light.id))")
        print("   └── archetype: '\(light.metadata.archetype ?? "nil")'")
        
        // ❌ ПРОБЛЕМА: archetype сейчас содержит подтип лампы (например "DESK LAMP"), 
        // а не ID комнаты! Это неправильно.
        // TODO: Нужно добавить отдельное поле для roomId
        
        // ВРЕМЕННОЕ РЕШЕНИЕ: Не используем archetype как roomId для ламп с выбранным подтипом
        if let archetype = light.metadata.archetype, !archetype.isEmpty {
            // Проверяем, является ли archetype подтипом лампы (а не ID комнаты)
            // Все подтипы из BulbTypeModels.swift содержат описательные названия
            let allKnownSubtypes = [
                // НАШИ ПОДТИПЫ (из BulbTypeModels)
                "TRADITIONAL LAMP", "DESK LAMP", "TABLE WASH",
                "CHRISTMAS TREE", "FLOOR SHADE", "FLOOR LANTERN", "BOLLARD", "GROUND SPOT", "RECESSED FLOOR", "LIGHT BAR",
                "WALL LANTERN", "WALL SHADE", "WALL SPOT", "DUAL WALL LIGHT",
                "PENDANT ROUND", "PENDANT HORIZONTAL", "CEILING ROUND", "CEILING SQUARE", "SINGLE SPOT", "DOUBLE SPOT", "RECESSED CEILING", "PEDANT SPOT", "CEILING HORIZONTAL", "CEILING TUBE",
                "SIGNATURE BULB", "ROUNDED BULB", "SPOT", "FLOOD LIGHT", "CANDELABRA BULB", "FILAMENT BULB", "MINI-BULB", "HUE LIGHTSTRIP", "LIGHTGUIDE", "PLAY LIGHT BAR", "HUE BLOOM", "HUE IRIS", "SMART PLUG", "HUE CENTRIS", "HUE TUBE", "HUE SIGNE", "FLOODLIGHT CAMERA", "TWILIGHT",
                // АРХЕТИПЫ PHILIPS HUE API (которые не являются комнатами)
                "SULTAN_BULB", "CLASSIC_BULB", "VINTAGE_BULB", "EDISON_BULB", "GLOBE_BULB", "CANDLE_BULB"
            ]
            
            if allKnownSubtypes.contains(archetype.uppercased()) {
                print("   └── archetype содержит подтип лампы, не комнату. Возвращаем 'Основная комната'")
                return "Основная комната"
            }
            
            // Если не подтип, пытаемся найти группу
            let roomName = findGroup(by: archetype)?.metadata?.name ?? "Без комнаты"
            print("   └── Найдена комната по archetype: '\(roomName)'")
            return roomName
        }
        
        print("   └── archetype пустой, возвращаем 'Без комнаты'")
        return "Без комнаты"
    }
    
    func getBulbType(for light: Light) -> String {
        print("📝 getBulbType для лампы '\(light.metadata.name)' (ID: \(light.id))")
        print("   └── archetype: '\(light.metadata.archetype ?? "nil")'")
        
        // Проверяем архетип (теперь это название подтипа)
        if let archetype = light.metadata.archetype, !archetype.isEmpty {
            // Возвращаем название подтипа напрямую (оно уже сохранено в archetype)
            print("   └── Возвращаем сохранённый подтип: '\(archetype)'")
            return archetype
        }
        
        // Если архетип пустой - возвращаем дефолтное значение
        print("   └── Архетип пустой, возвращаем 'Smart Light'")
        return "Smart Light"
    }

  
    
    /// Получить название категории по архетипу
    private func getCategoryName(for archetype: String) -> String {
        let archetypeLower = archetype.lowercased()
        
        // Определяем категорию на основе архетипа
        if archetypeLower.contains("traditional") || 
           archetypeLower.contains("desk") ||
           archetypeLower.contains("table") ||
           archetypeLower.contains("wash") {
            return "TABLE"
        }
        else if archetypeLower.contains("christmas") ||
                archetypeLower.contains("floor") ||
                archetypeLower.contains("shade") ||
                archetypeLower.contains("lantern") ||
                archetypeLower.contains("bollard") ||
                archetypeLower.contains("ground") ||
                archetypeLower.contains("recessed floor") ||
                archetypeLower.contains("light bar") {
            return "FLOOR"
        }
        else if archetypeLower.contains("wall") ||
                archetypeLower.contains("dual") {
            return "WALL"
        }
        else if archetypeLower.contains("pendant") ||
                archetypeLower.contains("ceiling") ||
                archetypeLower.contains("spot") ||
                archetypeLower.contains("recessed ceiling") ||
                archetypeLower.contains("tube") ||
                archetypeLower.contains("horizontal") {
            return "CEILING"
        }
        else {
            // Все остальные (signature, rounded, flood, candelabra, filament, mini, lightstrip, etc.)
            return "OTHER"
        }
    }
    
    func getBulbIcon(for light: Light) -> String {
        print("🖼️ getBulbIcon для лампы '\(light.metadata.name)' (ID: \(light.id))")
        print("   └── archetype: '\(light.metadata.archetype ?? "nil")'")
        
        // Сначала проверяем архетип (выбранную пользователем категорию)
        if let archetype = light.metadata.archetype, !archetype.isEmpty {
            // Получаем иконку для подтипа (по названию подтипа)
            let icon = getSubtypeIcon(for: archetype)
            print("   └── Получили иконку по архетипу '\(archetype)': '\(icon)'")
            return icon
        }
        
        // Если архетип не установлен - используем маппинг по комнатам (legacy)
        let roomName = getRoomName(for: light).lowercased()
        print("   └── Архетип пустой, используем комнату: '\(roomName)'")
        
        let defaultIcon: String
        switch roomName {
        case _ where roomName.contains("living"):
            defaultIcon = "f2" // Floor lamp icon for living room
        case _ where roomName.contains("bedroom"):
            defaultIcon = "t2" // Table lamp icon for bedroom
        case _ where roomName.contains("kitchen"):
            defaultIcon = "с3" // Ceiling round icon for kitchen
        case _ where roomName.contains("bathroom"):
            defaultIcon = "с3" // Ceiling round icon for bathroom
        case _ where roomName.contains("office"):
            defaultIcon = "t2" // Desk lamp icon for office
        default:
            defaultIcon = "o2" // Default bulb icon (rounded bulb)
        }
        
        print("   └── Возвращаем иконку по умолчанию: '\(defaultIcon)'")
        return defaultIcon
    }
    
    /// Получить иконку подтипа по его названию
    private func getSubtypeIcon(for subtypeName: String) -> String {
        let subtypeNameLower = subtypeName.lowercased()
        print("   🔍 getSubtypeIcon для подтипа: '\(subtypeName)' → lowercase: '\(subtypeNameLower)'")
        
        // Мапим названия подтипов на их иконки согласно BulbTypeModels.swift
        switch subtypeNameLower {
        // TABLE category (t1-t3)
        case "traditional lamp":
            return "t1"
        case "desk lamp":
            return "t2"
        case "table wash":
            return "t3"
            
        // FLOOR category (f1-f7)
        case "christmas tree":
            return "f1"
        case "floor shade":
            return "f2"
        case "floor lantern":
            return "f3"
        case "bollard":
            return "f4"
        case "ground spot":
            return "f5"
        case "recessed floor":
            return "f6"
        case "light bar":
            return "f7"
            
        // WALL category (w1-w4)
        case "wall lantern":
            return "w1"
        case "wall shade":
            return "w2"
        case "wall spot":
            return "w3"
        case "dual wall light":
            return "w4"
            
        // CEILING category (с1-с10)
        case "pendant round":
            return "с1"
        case "pendant horizontal":
            return "с2"
        case "ceiling round":
            return "с3"
        case "ceiling square":
            return "с4"
        case "single spot":
            return "с5"
        case "double spot":
            return "с6"
        case "recessed ceiling":
            return "с7"
        case "pedant spot":
            return "с8"
        case "ceiling horizontal":
            return "с9"
        case "ceiling tube":
            return "с10"
            
        // OTHER category (o1-o27)
        case "signature bulb":
            return "o1"
        case "rounded bulb":
            return "o2"
        case "spot":
            return "o3"
        case "flood light":
            return "o4"
        case "candelabra bulb":
            return "o5"
        case "filament bulb":
            return "o6"
        case "mini-bulb":
            return "o7"
        case "hue lightstrip":
            return "o8"
        case "lightguide":
            return "o9"
        case "play light bar":
            return "o15"
        case "hue bloom":
            return "o16"
        case "hue iris":
            return "o19"
        case "smart plug":
            return "o20"
        case "hue centris":
            return "o21"
        case "hue tube":
            return "o22"
        case "hue signe":
            return "o23"
        case "floodlight camera":
            return "o24"
        case "twilight":
            return "o25"
            
        // АРХЕТИПЫ PHILIPS HUE API
        case "sultan_bulb":
            return "o1" // Signature bulb иконка
        case "classic_bulb":
            return "o2" // Rounded bulb иконка
        case "vintage_bulb", "edison_bulb":
            return "o6" // Filament bulb иконка
        case "globe_bulb":
            return "o2" // Rounded bulb иконка
        case "candle_bulb":
            return "o5" // Candelabra bulb иконка
            
        default:
            // Если подтип не найден - возвращаем иконку категории
            let categoryIcon = getCategoryIcon(for: subtypeName)
            print("   ⚠️ Подтип '\(subtypeName)' не найден в маппинге, возвращаем категорию: '\(categoryIcon)'")
            return categoryIcon
        }
    }
    
    /// Получить иконку категории по архетипу
    private func getCategoryIcon(for archetype: String) -> String {
        let archetypeLower = archetype.lowercased()
        
        // Определяем категорию на основе архетипа
        if archetypeLower.contains("traditional") || 
           archetypeLower.contains("desk") ||
           archetypeLower.contains("table") ||
           archetypeLower.contains("wash") {
            return "table"
        }
        else if archetypeLower.contains("christmas") ||
                archetypeLower.contains("floor") ||
                archetypeLower.contains("shade") ||
                archetypeLower.contains("lantern") ||
                archetypeLower.contains("bollard") ||
                archetypeLower.contains("ground") ||
                archetypeLower.contains("recessed floor") ||
                archetypeLower.contains("light bar") {
            return "floor"
        }
        else if archetypeLower.contains("wall") ||
                archetypeLower.contains("dual") {
            return "wall"
        }
        else if archetypeLower.contains("pendant") ||
                archetypeLower.contains("ceiling") ||
                archetypeLower.contains("spot") ||
                archetypeLower.contains("recessed ceiling") ||
                archetypeLower.contains("tube") ||
                archetypeLower.contains("horizontal") {
            return "ceiling"
        }
        else {
            // Все остальные (signature, rounded, flood, candelabra, filament, mini, lightstrip, etc.)
            return "other"
        }
    }
    
    func getRoomIcon(for light: Light) -> String {
        let roomName = getRoomName(for: light).lowercased()
        
        // Маппинг комнат на иконки комнат
        switch roomName {
        case _ where roomName.contains("living"):
            return "tr1" // Traditional living room icon
        case _ where roomName.contains("bedroom"):
            return "tr2" // Traditional bedroom icon
        case _ where roomName.contains("kitchen"):
            return "pr1" // Practical kitchen icon
        case _ where roomName.contains("bathroom"):
            return "pr2" // Practical bathroom icon
        case _ where roomName.contains("office"):
            return "pr3" // Practical office icon
        case _ where roomName.contains("outdoor"):
            return "Ou1" // Outdoor icon
        default:
            return "tr1" // Default room icon
        }
    }
}

// MARK: - Extensions

extension LightControlService {
    /// Создать mock сервис для тестирования
    static func createMockService() -> LightControlService {
        let mockAppViewModel = AppViewModel(dataPersistenceService: nil)
        return LightControlService(appViewModel: mockAppViewModel)
    }
}
