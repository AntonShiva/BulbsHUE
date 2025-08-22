//
//  Conteiner.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct MainContainer: View {
    @EnvironmentObject var nav: NavigationManager
    
    var body: some View {
        Group {
            switch nav.currentRoute {
            case .environment: 
                EnvironmentView()
            case .schedule: 
                ScheduleView()
            case .music: 
                MusicView()
            case .addNewBulb:
                AddNewBulb()
            case .searchResults:
                // Этот экран больше не нужен как отдельный, так как состояние отслеживается в AddNewBulb
                AddNewBulb()
            case .selectCategories:
                // Этот экран также управляется состоянием в AddNewBulb
                AddNewBulb()
            case .menuView:
                // Показываем MenuView с выбранной лампой или комнатой
                if let selectedLight = nav.selectedLightForMenu {
                    MenuView(
                        bulbName: selectedLight.metadata.name,
                        bulbIcon: getBulbIcon(for: selectedLight),
                        bulbType: getBulbType(for: selectedLight)
                    )
                } else if let selectedRoom = nav.selectedRoomForMenu {
                    MenuItemRooms(
                        roomName: selectedRoom.name,
                        roomType: getRoomType(for: selectedRoom),
                        bulbCount: getRoomLightCount(for: selectedRoom),
                        baseColor: getRoomColor(for: selectedRoom)
                    )
                } else {
                    // Fallback если ничего не выбрано
                    EnvironmentView()
                }
            case .development:
                DevelopmentMenuView()
            case .migrationDashboard:
                MigrationDashboardView()
            case .addRoom:
                AddNewRoom()
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    private func getBulbIcon(for light: Light) -> String {
        // Возвращаем иконку из пользовательских настроек или дефолтную
        return light.metadata.userSubtypeIcon ?? "f1"
    }
    
    private func getBulbType(for light: Light) -> String {
        // Возвращаем тип из пользовательских настроек или дефолтный
        return light.metadata.userSubtypeName ?? light.metadata.archetype ?? "Smart Light"
    }
    
    // MARK: - Room Helper Methods
    
    private func getRoomType(for room: RoomEntity) -> String {
        // Возвращаем тип комнаты из модели данных
        return room.type.displayName
    }
    
    private func getRoomLightCount(for room: RoomEntity) -> Int {
        // Получаем количество ламп в комнате
        return room.lightCount
    }
    
    private func getRoomColor(for room: RoomEntity) -> Color {
        // TODO: Получить цвет комнаты из настроек
        return .cyan
    }
}
