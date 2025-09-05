//
//  MenuItemRooms.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/22/25.
//

import SwiftUI
import Combine

/// Меню настроек для комнаты (обновленная версия, использующая универсальные компоненты)
/// Использует UniversalMenuView для единообразного интерфейса с меню ламп
struct MenuItemRooms: View {
    let roomId: String
    let roomName: String
    /// Тип комнаты (пользовательский подтип)
    let roomType: String
    /// Количество подключенных ламп в комнате
    let bulbCount: Int
    /// Базовый цвет для фона компонента
    let baseColor: Color
    
    @Environment(NavigationManager.self) private var nav
    
    /// Набор cancellables для хранения подписок Combine
    @State private var cancellables = Set<AnyCancellable>()
    
    /// Инициализатор для создания меню комнаты
    /// - Parameters:
    ///   - roomId: ID комнаты
    ///   - roomName: Название комнаты
    ///   - roomType: Тип комнаты
    ///   - bulbCount: Количество ламп в комнате
    ///   - baseColor: Базовый цвет для интерфейса
    init(roomId: String,
         roomName: String, 
         roomType: String, 
         bulbCount: Int, 
         baseColor: Color = .cyan) {
        self.roomId = roomId
        self.roomName = roomName
        self.roomType = roomType
        self.bulbCount = bulbCount
        self.baseColor = baseColor
    }
    
    var body: some View {
        // Используем данные из nav.selectedRoomForMenu для реактивности
        let currentRoom = nav.selectedRoomForMenu
        let displayRoomName = currentRoom?.subtypeName ?? roomName // ✅ Подтип как название (HOME)
        let displayRoomType = currentRoom?.type.parentEnvironmentType.displayName.uppercased() ?? roomType // ✅ Тип как подзаголовок (LEVELS)
        let displayBulbCount = currentRoom?.lightCount ?? bulbCount
        
        // Используем универсальное меню с конфигурацией для комнаты
        UniversalMenuView(
            itemData: .room(
                title: displayRoomName, // HOME (подтип)
                subtitle: displayRoomType, // LEVELS (тип)
                bulbCount: displayBulbCount,
                baseColor: baseColor,
                roomId: roomId
            ),
            menuConfig: .forRoom(
                onChangeType: {
                    print("🏠 Change room type pressed")
                    // TODO: Реализовать смену типа комнаты
                },
                onTypeChanged: { typeName, iconName in
                    print("✅ Room type changed to: \(typeName), icon: \(iconName)")
                    // TODO: Сохранить новый тип комнаты в модель данных
                    // Здесь нужно обновить данные комнаты с новым типом
                },
                onRename: { newName in
                    print("✏️ Rename room to: \(newName)")
                    // Переименование реализовано в UniversalMenuView через Use Cases
                },
                onReorganize: {
                    print("📋 Reorganize room pressed")
                    // TODO: Реализовать реорганизацию комнаты (перенос ламп)
                },
                onDelete: {
                    print("🗑️ Delete room pressed")
                    
                    // Получаем текущую выбранную комнату из NavigationManager
                    guard let currentRoom = self.nav.selectedRoomForMenu else {
                        print("❌ Ошибка: Нет выбранной комнаты для удаления")
                        return
                    }
                    
                    // Используем DeleteRoomUseCase для удаления комнаты
                    let deleteRoomUseCase = DIContainer.shared.deleteRoomUseCase
                    
                    // Выполняем удаление через Combine
                    deleteRoomUseCase.execute(currentRoom.id)
                        .receive(on: DispatchQueue.main)
                        .sink(
                            receiveCompletion: { completion in
                                switch completion {
                                case .finished:
                                    print("✅ Комната '\(currentRoom.subtypeName)' успешно удалена")
                                    
                                    // Очищаем selectedRoomForMenu
                                    self.nav.selectedRoomForMenu = nil
                                    
                                    // Закрываем меню
                                    self.nav.hideMenuView()
                                    
                                case .failure(let error):
                                    print("❌ Ошибка при удалении комнаты: \(error.localizedDescription)")
                                }
                            },
                            receiveValue: { _ in
                                // Операция завершена успешно
                            }
                        )
                        .store(in: &cancellables)
                }
            )
        )
    }
}

#Preview("Room with 5 bulbs") {
    MenuItemRooms(
        roomId: "preview_room_1",
        roomName: "LIVING ROOM", 
        roomType: "RECREATION", 
        bulbCount: 5, 
        baseColor: .cyan
    )
    .environment(NavigationManager.shared)
}

#Preview("Room with 2 bulbs") {
    MenuItemRooms(
        roomId: "preview_room_2",
        roomName: "BEDROOM", 
        roomType: "PERSONAL", 
        bulbCount: 2, 
        baseColor: .orange
    )
    .environment(NavigationManager.shared)
}

#Preview("Empty room") {
    MenuItemRooms(
        roomId: "preview_room_3",
        roomName: "KITCHEN", 
        roomType: "PRACTICAL", 
        bulbCount: 0, 
        baseColor: .green
    )
    .environment(NavigationManager.shared)
}
