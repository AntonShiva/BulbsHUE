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
        // Используем архетип лампы как ID комнаты
        guard let roomId = light.metadata.archetype else {
            return "Без комнаты"
        }
        
        return findGroup(by: roomId)?.metadata?.name ?? "Без комнаты"
    }
    
    func getBulbType(for light: Light) -> String {
        // Сначала проверяем архетип, который устанавливает пользователь
        if let archetype = light.metadata.archetype, !archetype.isEmpty {
            return getCategoryName(for: archetype)
        }
        
        // Если архетип не установлен - используем тип по умолчанию
        switch light.type {
        case "light":
            return "Smart Light"
        case "grouped_light":
            return "Group Light"
        default:
            return light.type.capitalized
        }
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
        // Сначала проверяем архетип (выбранную пользователем категорию)
        if let archetype = light.metadata.archetype, !archetype.isEmpty {
            return getCategoryIcon(for: archetype)
        }
        
        // Если архетип не установлен - используем маппинг по комнатам (legacy)
        let roomName = getRoomName(for: light).lowercased()
        
        switch roomName {
        case _ where roomName.contains("living"):
            return "floor" // Floor category icon
        case _ where roomName.contains("bedroom"):
            return "table" // Table category icon
        case _ where roomName.contains("kitchen"):
            return "ceiling" // Ceiling category icon
        case _ where roomName.contains("bathroom"):
            return "ceiling" // Ceiling category icon
        case _ where roomName.contains("office"):
            return "table" // Table category icon
        default:
            return "floor" // Default floor category icon
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
