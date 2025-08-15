//
//  GroupEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - Domain Entity для группы
/// Чистая доменная модель группы без зависимостей от API
struct GroupEntity: Equatable, Identifiable {
    let id: String
    let name: String
    let lightIds: [String]
    let isOn: Bool
    let brightness: Double?
    let groupType: GroupType
    
    enum GroupType: String, CaseIterable {
        case room = "room"
        case zone = "zone"
        case entertainment = "entertainment"
        case bridge_home = "bridge_home"
        
        var displayName: String {
            switch self {
            case .room: return "Room"
            case .zone: return "Zone"
            case .entertainment: return "Entertainment"
            case .bridge_home: return "Bridge Home"
            }
        }
    }
    
    /// Инициализатор из существующей модели HueGroup
    init(from group: HueGroup) {
        self.id = group.id.isEmpty ? UUID().uuidString : group.id
        self.name = group.metadata?.name ?? "Unnamed Group"
        // В API v2 связь лампа-группа определяется через отдельные запросы
        // Здесь оставляем пустой массив, заполняется через Repository
        self.lightIds = []
        self.isOn = group.on?.on ?? false
        self.brightness = group.dimming?.brightness
        self.groupType = GroupType(rawValue: group.group_type ?? "room") ?? .room
    }
    
    /// Инициализатор для создания новой сущности
    init(id: String, 
         name: String, 
         lightIds: [String], 
         isOn: Bool = false, 
         brightness: Double? = nil, 
         groupType: GroupType = .room) {
        self.id = id
        self.name = name
        self.lightIds = lightIds
        self.isOn = isOn
        self.brightness = brightness
        self.groupType = groupType
    }
}
