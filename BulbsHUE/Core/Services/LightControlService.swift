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
        print("   └── apiArchetype: '\(light.metadata.archetype ?? "nil")'")
        
        // ✅ НОВАЯ ЛОГИКА: archetype теперь ТОЛЬКО пользовательский подтип лампы
        // Для комнат нужен отдельный механизм (например, через группы или отдельное поле)
        
        // TODO: Реализовать отдельное поле roomId в Light/LightDataModel
        // Пока возвращаем дефолтную комнату
        
        print("   └── Возвращаем дефолтную комнату (archetype теперь только для подтипов ламп)")
        return "Основная комната"
    }
    
    func getBulbType(for light: Light) -> String {
        print("📝 getBulbType для лампы '\(light.metadata.name)' (ID: \(light.id))")
        print("   └── userSubtypeName: '\(light.metadata.userSubtypeName ?? "nil")' | apiArchetype: '\(light.metadata.archetype ?? "nil")'")
        
        // Возвращаем пользовательский подтип если задан
        if let userSubtype = light.metadata.userSubtypeName, !userSubtype.isEmpty {
            print("   └── Возвращаем пользовательский подтип: '\(userSubtype)'")
            return userSubtype
        }
        
        // 🔁 Fallback: пробуем взять сохранённый подтип из БД (если ещё не подмешан в текущий light)
        if let saved = appViewModel?.dataService?.fetchAssignedLights().first(where: { $0.id == light.id }),
           let savedSubtype = saved.metadata.userSubtypeName, !savedSubtype.isEmpty {
            print("   └── Fallback: подтип из БД: '\(savedSubtype)'")
            return savedSubtype
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
        print("   └── userSubtypeIcon: '\(light.metadata.userSubtypeIcon ?? "nil")'")
        print("   └── userSubtypeName: '\(light.metadata.userSubtypeName ?? "nil")' | apiArchetype: '\(light.metadata.archetype ?? "nil")'")
        
        // ✅ НОВАЯ ЛОГИКА: Приоритет у пользовательской иконки подтипа
        if let userIcon = light.metadata.userSubtypeIcon, !userIcon.isEmpty {
            print("   └── Возвращаем пользовательскую иконку: '\(userIcon)'")
            return userIcon
        }
        
        // Если пользовательской иконки нет, но есть подтип - пытаемся найти иконку по названию подтипа
        if let userSubtype = light.metadata.userSubtypeName, !userSubtype.isEmpty {
            let icon = getSubtypeIcon(for: userSubtype)
            print("   └── Получили иконку по названию подтипа '\(userSubtype)': '\(icon)'")
            return icon
        }
        
        // 🔁 Fallback: пробуем взять сохранённые значения из БД
        if let saved = appViewModel?.dataService?.fetchAssignedLights().first(where: { $0.id == light.id }) {
            if let savedIcon = saved.metadata.userSubtypeIcon, !savedIcon.isEmpty {
                print("   └── Fallback: пользовательская иконка из БД: '\(savedIcon)'")
                return savedIcon
            }
            if let savedSubtype = saved.metadata.userSubtypeName, !savedSubtype.isEmpty {
                let icon = getSubtypeIcon(for: savedSubtype)
                print("   └── Fallback: иконка по названию подтипа из БД '\(savedSubtype)': '\(icon)'")
                return icon
            }
        }
        
        // Если ничего нет - используем дефолтную иконку
        let defaultIcon = "o2" // Rounded bulb
        print("   └── Возвращаем дефолтную иконку: '\(defaultIcon)'")
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
            
        // CEILING category (c1-c10)
        case "pendant round":
            return "c1"
        case "pendant horizontal":
            return "c2"
        case "ceiling round":
            return "c3"
        case "ceiling square":
            return "c4"
        case "single spot":
            return "c5"
        case "double spot":
            return "c6"
        case "recessed ceiling":
            return "c7"
        case "pedant spot":
            return "c8"
        case "ceiling horizontal":
            return "c9"
        case "ceiling tube":
            return "c10"
            
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
        case "lightguide basic":
            return "o7"
        case "lightguide slim":
            return "o8"
        case "lightguide wide":
            return "o9"
        case "lightguide curved":
            return "o10"
        case "lightguide flex":
            return "o11"
        case "twilight":
            return "o12"
        case "twilight pro":
            return "o13"
        case "twilight mini":
            return "o14"
        case "play light bar":
            return "o16"
        case "play light bar dual":
            return "o17"
        case "hue bloom":
            return "o20"
        case "hue bloom mini":
            return "o21"
        case "candle socket":
            return "o15"
        case "christmas tree":
            return "o18"
        case "hue iris":
            return "o19"
        case "unknown":
            return "o22"
        case "stripp":
            return "o23"
        case "bollard":
            return "o24"
        case "wall washer":
            return "o25"
        case "classic fixture":
            return "o26"
        case "hue centris":
            return "o27"
            
        // ⚠️ Больше не мапим API-архетипы на иконки напрямую.
        // Если пришло сюда API-значение — пусть обработается как категория в default.
            
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
