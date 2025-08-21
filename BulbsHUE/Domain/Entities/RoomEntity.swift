//
//  RoomEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - Domain Entity для комнаты
/// Представляет группу ламп в определенной комнате
struct RoomEntity: Equatable, Identifiable {
    let id: String
    let name: String
    let type: RoomSubType
    let iconName: String // ✅ Иконка подтипа, выбранная пользователем
    let lightIds: [String]
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    /// Количество ламп в комнате
    var lightCount: Int {
        return lightIds.count
    }
    
    /// Пустая ли комната
    var isEmpty: Bool {
        return lightIds.isEmpty
    }
}

// MARK: - Room Types (конкретные типы комнат)
enum RoomSubType: String, CaseIterable {
    // Traditional rooms
    case livingRoom = "LIVING_ROOM"
    case bedroom = "BEDROOM"
    case kitchen = "KITCHEN"
    case diningRoom = "DINING_ROOM"
    case bathroom = "BATHROOM"
    case hallway = "HALLWAY"
    case office = "OFFICE"
    
    // Outdoor areas
    case garden = "GARDEN"
    case patio = "PATIO"
    case balcony = "BALCONY"
    case driveway = "DRIVEWAY"
    case entrance = "ENTRANCE"
    
    // Practical spaces
    case garage = "GARAGE"
    case basement = "BASEMENT"
    case laundryRoom = "LAUNDRY_ROOM"
    case storage = "STORAGE"
    case workshop = "WORKSHOP"
    case pantry = "PANTRY"
    
    // Recreation areas
    case gameRoom = "GAME_ROOM"
    case homeTheater = "HOME_THEATER"
    case gym = "GYM"
    case library = "LIBRARY"
    case musicRoom = "MUSIC_ROOM"
    case artStudio = "ART_STUDIO"
    
    var displayName: String {
        switch self {
        // Traditional
        case .livingRoom: return "Living Room"
        case .bedroom: return "Bedroom"
        case .kitchen: return "Kitchen"
        case .diningRoom: return "Dining Room"
        case .bathroom: return "Bathroom"
        case .hallway: return "Hallway"
        case .office: return "Office"
        
        // Outdoor
        case .garden: return "Garden"
        case .patio: return "Patio"
        case .balcony: return "Balcony"
        case .driveway: return "Driveway"
        case .entrance: return "Entrance"
        
        // Practical
        case .garage: return "Garage"
        case .basement: return "Basement"
        case .laundryRoom: return "Laundry Room"
        case .storage: return "Storage"
        case .workshop: return "Workshop"
        case .pantry: return "Pantry"
        
        // Recreation
        case .gameRoom: return "Game Room"
        case .homeTheater: return "Home Theater"
        case .gym: return "Gym"
        case .library: return "Library"
        case .musicRoom: return "Music Room"
        case .artStudio: return "Art Studio"
        }
    }
    
    var parentEnvironmentType: RoomType {
        switch self {
        case .livingRoom, .bedroom, .kitchen, .diningRoom, .bathroom, .hallway, .office:
            return .traditional
        case .garden, .patio, .balcony, .driveway, .entrance:
            return .outdoor
        case .garage, .basement, .laundryRoom, .storage, .workshop, .pantry:
            return .practical
        case .gameRoom, .homeTheater, .gym, .library, .musicRoom, .artStudio:
            return .recreation
        }
    }
}

// MARK: - Environment Types (категории окружений для группировки комнат)
enum RoomType: String, CaseIterable {
    case traditional = "TRADITIONAL"
    case outdoor = "OUTDOOR"
    case practical = "PRACTICAL"
    case recreation = "RECREATION"
    
    var displayName: String {
        switch self {
        case .traditional: return "Traditional"
        case .outdoor: return "Outdoor"
        case .practical: return "Practical"
        case .recreation: return "Recreation"
        }
    }
}
