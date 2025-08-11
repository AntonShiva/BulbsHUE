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
            return archetype
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
    
    func getBulbIcon(for light: Light) -> String {
        let roomName = getRoomName(for: light).lowercased()
        
        // Маппинг комнат на иконки ламп
        switch roomName {
        case _ where roomName.contains("living"):
            return "f2" // Floor lamp for living room
        case _ where roomName.contains("bedroom"):
            return "t1" // Table lamp for bedroom
        case _ where roomName.contains("kitchen"):
            return "c1" // Ceiling lamp for kitchen
        case _ where roomName.contains("bathroom"):
            return "c2" // Ceiling lamp for bathroom
        case _ where roomName.contains("office"):
            return "t2" // Table lamp for office
        default:
            return "f2" // Default floor lamp
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
