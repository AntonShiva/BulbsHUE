//
//  RoomTypeModels.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 18.08.2025.
//

import SwiftUI
import Combine

// MARK: - Модель подтипа комнаты
struct RoomSubtype: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let iconName: String
    let roomType: RoomSubType // Связь с enum из RoomEntity
    var isSelected: Bool = false
    
    // Хэширование для Set
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Сравнение для Hashable
    static func == (lhs: RoomSubtype, rhs: RoomSubtype) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Модель категории комнаты
struct RoomCategory: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let iconWidth: CGFloat
    let iconHeight: CGFloat
    var subtypes: [RoomSubtype]
    
    init(name: String, iconName: String, iconWidth: CGFloat = 24, iconHeight: CGFloat = 24, subtypes: [RoomSubtype] = []) {
        self.name = name
        self.iconName = iconName
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.subtypes = subtypes
    }
}

// MARK: - Менеджер данных категорий комнат
class RoomCategoryManager: ObservableObject {
    @Published var selectedSubtype: UUID? = nil // Только один выбранный подтип
    
    // Словарь с названиями подтипов для каждого типа (согласно скриншоту)
    private let subtypeNames: [String: [String]] = [
        "TRADITIONAL": [
            "LIVING ROOM",       // tr1
            "KITCHEN",           // tr2
            "DINING",            // tr3
            "BEDROOM",           // tr4
            "KIDS BEDROOM",      // tr5
            "BATHROOM",          // tr6
            "NURSERY",           // tr7
            "OFFICE",            // tr8
            "GUEST ROOM"         // tr9
        ],
        "PRACTICAL": [
            "TOILET",            // pr1
            "STAIRCASE",         // pr2
            "HALLWAY",           // pr3
            "LAUNDRY ROOM",      // pr4
            "STORAGE",           // pr5
            "CLOSET",            // pr6
            "GARAGE",            // pr7
            "OTHER"              // pr8
        ],
        "RECREATION": [
            "GYM",               // re1
            "LOUNGE",            // re2
            "TV",                // re3
            "COMPUTER",          // re4
            "RECREATION",        // re5
            "GAMING ROOM",       // re6
            "MUSIC ROOM",        // re7
            "LIBRARY",           // re8
            "STUDIO"             // re9
        ],
        "OUTSIDE": [
            "BACKYARD",          // Ou1
            "PATIO",             // Ou2
            "BALCONY",           // Ou3
            "DRIVEWAY",          // Ou4
            "CARPORT",           // Ou5
            "FRONT DOOR",        // Ou6
            "PORCH",             // Ou7
            "BARBECUE",          // Ou8
            "POOL"               // Ou9
        ],
        "LEVELS": [
            "DOWNSTAIRS",        // Liv1
            "UPSTAIRS",          // Liv2
            "TOP FLOOR",         // Liv3
            "ATTIC",             // Liv4
            "HOME"               // Liv5
        ]
    ]
    
        // Генерируем категории комнат с подтипами
    lazy var roomCategories: [RoomCategory] = {
        return [
            generateRoomCategory(name: "TRADITIONAL", iconName: "Traditional", iconPrefix: "tr", count: 9),
            generateRoomCategory(name: "PRACTICAL", iconName: "Practical", iconPrefix: "pr", count: 8),
            generateRoomCategory(name: "RECREATION", iconName: "Recreation", iconPrefix: "re", count: 9),
            generateRoomCategory(name: "OUTSIDE", iconName: "Outside", iconPrefix: "Ou", count: 9),
            generateRoomCategory(name: "LEVELS", iconName: "Levels", iconPrefix: "Liv", count: 5)
        ]
    }()
    
   
    
    // Генерирует категорию комнаты с подтипами
    private func generateRoomCategory(
        name: String,
        iconName: String,
        iconWidth: CGFloat = 24,
        iconHeight: CGFloat = 24,
        iconPrefix: String,
        count: Int
    ) -> RoomCategory {
        let names = subtypeNames[name] ?? []
        let subtypes = (1...count).map { index in
            let subtypeName = names.indices.contains(index - 1) ? names[index - 1] : "\(name) TYPE \(index)"
            let roomSubType = mapToRoomSubType(subtypeName)
            return RoomSubtype(
                name: subtypeName,
                iconName: "\(iconPrefix)\(index)",
                roomType: roomSubType
            )
        }
        
        return RoomCategory(
            name: name,
            iconName: iconName,
            iconWidth: iconWidth,
            iconHeight: iconHeight,
            subtypes: subtypes
        )
    }
    
    // Мапинг названий подтипов к enum RoomSubType
    private func mapToRoomSubType(_ name: String) -> RoomSubType {
        switch name {
        // Traditional
        case "LIVING ROOM": return .livingRoom
        case "KITCHEN": return .kitchen
        case "DINING": return .diningRoom
        case "BEDROOM": return .bedroom
        case "KIDS BEDROOM": return .bedroom // Используем .bedroom для детской
        case "BATHROOM": return .bathroom
        case "NURSERY": return .bedroom // Используем .bedroom для детской
        case "OFFICE": return .office
        case "GUEST ROOM": return .bedroom // Используем .bedroom для гостевой
        
        // Practical
        case "TOILET": return .bathroom // Используем .bathroom для туалета
        case "STAIRCASE": return .hallway // Используем .hallway для лестницы
        case "HALLWAY": return .hallway
        case "LAUNDRY ROOM": return .laundryRoom
        case "STORAGE": return .storage
        case "CLOSET": return .storage // Используем .storage для гардероба
        case "GARAGE": return .garage
        case "OTHER": return .storage // Используем .storage для других помещений
        
        // Recreation
        case "GYM": return .gym
        case "LOUNGE": return .gameRoom // Используем .gameRoom для лаунжа
        case "TV": return .homeTheater // Используем .homeTheater для ТВ комнаты
        case "COMPUTER": return .office // Используем .office для компьютерной комнаты
        case "RECREATION": return .gameRoom
        case "GAMING ROOM": return .gameRoom
        case "MUSIC ROOM": return .musicRoom
        case "LIBRARY": return .library
        case "STUDIO": return .artStudio
        
        // Outside
        case "BACKYARD": return .garden // Используем .garden для заднего двора
        case "PATIO": return .patio
        case "BALCONY": return .balcony
        case "DRIVEWAY": return .driveway
        case "CARPORT": return .garage // Используем .garage для навеса
        case "FRONT DOOR": return .entrance
        case "PORCH": return .entrance // Используем .entrance для крыльца
        case "BARBECUE": return .garden // Используем .garden для барбекю зоны
        case "POOL": return .garden // Используем .garden для бассейна
        
        // Levels (используем подходящие типы)
        case "DOWNSTAIRS": return .livingRoom
        case "UPSTAIRS": return .bedroom
        case "TOP FLOOR": return .bedroom
        case "ATTIC": return .storage
        case "HOME": return .livingRoom
        
        // Дефолтное значение
        default: return .livingRoom
        }
    }
    
    
    // MARK: - Методы управления выбором
    
    /// Выбирает подтип (отменяет предыдущий выбор)
    func selectSubtype(_ subtype: RoomSubtype) {
        if selectedSubtype == subtype.id {
            // Если тот же подтип - отменяем выбор
            selectedSubtype = nil
        } else {
            // Выбираем новый подтип
            selectedSubtype = subtype.id
        }
    }
    
    /// Проверяет, выбран ли конкретный подтип
    func isSubtypeSelected(_ subtype: RoomSubtype) -> Bool {
        return selectedSubtype == subtype.id
    }
    
    /// Получает выбранный подтип
    func getSelectedSubtype() -> RoomSubtype? {
        for roomCategory in roomCategories {
            for subtype in roomCategory.subtypes {
                if subtype.id == selectedSubtype {
                    return subtype
                }
            }
        }
        return nil
    }
    
    /// Проверяет, есть ли выбранный подтип
    var hasSelection: Bool {
        return selectedSubtype != nil
    }
    
    /// Сбрасывает выбор
    func clearSelection() {
        selectedSubtype = nil
    }
}
