//
//  MenuItemRooms.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/22/25.
//

import SwiftUI

/// Меню настроек для комнаты (обновленная версия, использующая универсальные компоненты)
/// Использует UniversalMenuView для единообразного интерфейса с меню ламп
struct MenuItemRooms: View {
    let roomName: String
    /// Тип комнаты (пользовательский подтип)
    let roomType: String
    /// Количество подключенных ламп в комнате
    let bulbCount: Int
    /// Базовый цвет для фона компонента
    let baseColor: Color
    
    /// Инициализатор для создания меню комнаты
    /// - Parameters:
    ///   - roomName: Название комнаты
    ///   - roomType: Тип комнаты
    ///   - bulbCount: Количество ламп в комнате
    ///   - baseColor: Базовый цвет для интерфейса
    init(roomName: String, 
         roomType: String, 
         bulbCount: Int, 
         baseColor: Color = .cyan) {
        self.roomName = roomName
        self.roomType = roomType
        self.bulbCount = bulbCount
        self.baseColor = baseColor
    }
    
    var body: some View {
        // Используем универсальное меню с конфигурацией для комнаты
        UniversalMenuView(
            itemData: .room(
                title: roomName,
                subtitle: roomType,
                bulbCount: bulbCount,
                baseColor: baseColor
            ),
            menuConfig: .forRoom(
                onChangeType: {
                    print("🏠 Change room type pressed")
                    // TODO: Реализовать смену типа комнаты
                },
                onRename: { newName in
                    print("✏️ Rename room to: \(newName)")
                    // TODO: Реализовать переименование комнаты
                },
                onReorganize: {
                    print("📋 Reorganize room pressed")
                    // TODO: Реализовать реорганизацию комнаты (перенос ламп)
                },
                onDelete: {
                    print("🗑️ Delete room pressed")
                    // TODO: Реализовать удаление комнаты
                }
            )
        )
    }
}

#Preview("Room with 5 bulbs") {
    MenuItemRooms(
        roomName: "LIVING ROOM", 
        roomType: "RECREATION", 
        bulbCount: 5, 
        baseColor: .cyan
    )
    .environmentObject(NavigationManager.shared)
}

#Preview("Room with 2 bulbs") {
    MenuItemRooms(
        roomName: "BEDROOM", 
        roomType: "PERSONAL", 
        bulbCount: 2, 
        baseColor: .orange
    )
    .environmentObject(NavigationManager.shared)
}

#Preview("Empty room") {
    MenuItemRooms(
        roomName: "KITCHEN", 
        roomType: "PRACTICAL", 
        bulbCount: 0, 
        baseColor: .green
    )
    .environmentObject(NavigationManager.shared)
}
