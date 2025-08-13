//
//  BulbTypeModels.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 06.08.2025.
//

import SwiftUI
import Combine

// MARK: - Модель подтипа лампы
struct LampSubtype: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let iconName: String
    var isSelected: Bool = false
    
    // Хэширование для Set
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Сравнение для Hashable
    static func == (lhs: LampSubtype, rhs: LampSubtype) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Модель типа лампы
struct BulbType: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let iconWidth: CGFloat
    let iconHeight: CGFloat
    var subtypes: [LampSubtype]
    
    init(name: String, iconName: String, iconWidth: CGFloat = 24, iconHeight: CGFloat = 24, subtypes: [LampSubtype] = []) {
        self.name = name
        self.iconName = iconName
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.subtypes = subtypes
    }
}

// MARK: - Менеджер данных типов ламп
class BulbTypeManager: ObservableObject {
    @Published var selectedSubtype: UUID? = nil // Только один выбранный подтип
    
    // Словарь с названиями подтипов для каждого типа (согласно скриншоту)
    private let subtypeNames: [String: [String]] = [
        "TABLE": [
            "TRADITIONAL LAMP",    // t1
            "DESK LAMP",          // t2
            "TABLE WASH"          // t3
        ],
        "FLOOR": [
            "CHRISTMAS TREE",     // f1
            "FLOOR SHADE",        // f2
            "FLOOR LANTERN",      // f3
            "BOLLARD",            // f4
            "GROUND SPOT",        // f5
            "RECESSED FLOOR",     // f6
            "LIGHT BAR"         // f7
        ],
        "WALL": [
            "WALL LANTERN",       // w1
            "WALL SHADE",         // w2
            "WALL SPOT",          // w3
            "DUAL WALL LIGHT"     // w4
        ],
        "CEILING": [
            "PENDANT ROUND",      // c1
            "PENDANT HORIZONTAL", // c2
            "CEILING ROUND",      // c3
            "CEILING SQUARE",     // c4
            "SINGLE SPOT",        // c5
            "DOUBLE SPOT",        // c6
            "RECESSED CEILING",   // c7
            "PEDANT SPOT",        // c8
            "CEILING HORIZONTAL", // c9
            "CEILING TUBE"        // c10
        ],
        "OTHER": [
            "SIGNATURE BULB",     // o1
            "ROUNDED BULB",       // o2
            "SPOT",               // o3
            "FLOOD LIGHT",        // o4
            "CANDELABRA BULB",    // o5
            "FILAMENT BULB",      // o6
            "MINI-BULB",          // o7
            "HUE LIGHTSTRIP",     // o8
            "LIGHTGUIDE BASIC",   // o9
            "LIGHTGUIDE SLIM",    // o10
            "LIGHTGUIDE WIDE",    // o11
            "LIGHTGUIDE CURVED",  // o12
            "LIGHTGUIDE FLEX",    // o13
            "HUE LIGHTSTRIP PLUS", // o14
            "PLAY LIGHT BAR",     // o15
            "HUE BLOOM",          // o16
            "PLAY LIGHT BAR DUAL", // o17
            "HUE BLOOM MINI",     // o18
            "HUE IRIS",           // o19
            "SMART PLUG",         // o20
            "HUE CENTRIS",        // o21
            "HUE TUBE",           // o22
            "HUE SIGNE",          // o23
            "FLOODLIGHT CAMERA",  // o24
            "TWILIGHT",           // o25
            "TWILIGHT PRO",       // o26
            "TWILIGHT MINI"       // o27
        ]
    ]
    
    // Генерируем типы ламп с подтипами
    lazy var bulbTypes: [BulbType] = {
        return [
            generateBulbType(name: "TABLE", iconName: "table", iconPrefix: "t", count: 3),
            generateBulbType(name: "FLOOR", iconName: "floor", iconPrefix: "f", count: 7),
            generateBulbType(name: "WALL", iconName: "wall", iconPrefix: "w", count: 4),
            generateBulbType(name: "CEILING", iconName: "ceiling", iconWidth: 24, iconHeight: 20, iconPrefix: "c", count: 10),
            generateBulbType(name: "OTHER", iconName: "other", iconPrefix: "o", count: 27)
        ]
    }()
    
    // Генерирует тип лампы с подтипами
    private func generateBulbType(
        name: String,
        iconName: String,
        iconWidth: CGFloat = 24,
        iconHeight: CGFloat = 24,
        iconPrefix: String,
        count: Int
    ) -> BulbType {
        let names = subtypeNames[name] ?? []
        let subtypes = (1...count).map { index in
            let subtypeName = names.indices.contains(index - 1) ? names[index - 1] : "\(name) TYPE \(index)"
            return LampSubtype(
                name: subtypeName,
                iconName: "\(iconPrefix)\(index)"
            )
        }
        
        return BulbType(
            name: name,
            iconName: iconName,
            iconWidth: iconWidth,
            iconHeight: iconHeight,
            subtypes: subtypes
        )
    }
    
    // MARK: - Методы управления выбором
    
    /// Выбирает подтип (отменяет предыдущий выбор)
    func selectSubtype(_ subtype: LampSubtype) {
        if selectedSubtype == subtype.id {
            // Если тот же подтип - отменяем выбор
            selectedSubtype = nil
        } else {
            // Выбираем новый подтип
            selectedSubtype = subtype.id
        }
    }
    
    /// Проверяет, выбран ли подтип
    func isSubtypeSelected(_ subtype: LampSubtype) -> Bool {
        selectedSubtype == subtype.id
    }
    
    /// Получает обновленный подтип с актуальным состоянием выбора
    func getUpdatedSubtype(_ subtype: LampSubtype) -> LampSubtype {
        var updatedSubtype = subtype
        updatedSubtype.isSelected = isSubtypeSelected(subtype)
        return updatedSubtype
    }
    
    /// Получает выбранный подтип
    func getSelectedSubtype() -> LampSubtype? {
        guard let selectedId = selectedSubtype else { return nil }
        return bulbTypes.flatMap { $0.subtypes }.first { $0.id == selectedId }
    }
    
    /// Очищает выбор
    func clearSelection() {
        selectedSubtype = nil
    }
    
    /// Проверяет, есть ли выбранный подтип
    var hasSelection: Bool {
        selectedSubtype != nil
    }
}
