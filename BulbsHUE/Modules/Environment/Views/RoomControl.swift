//
//  RoomControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI
import Combine

/// Компонент для управления комнатой (всеми лампами в ней)
/// Аналогично ItemControl, но для комнат
struct RoomControl: View {
    // MARK: - Environment Objects
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var nav: NavigationManager
    
    // MARK: - Properties
    
    /// Комната для отображения и управления
    let room: RoomEntity
    
    /// Изолированная ViewModel для этой конкретной комнаты
    @StateObject private var roomControlViewModel: RoomControlViewModel
    
    // MARK: - Initialization
    
    /// Инициализация с созданием изолированной ViewModel для комнаты
    /// - Parameter room: Комната для управления
    init(room: RoomEntity) {
        self.room = room
        
        // Создаем изолированную ViewModel для этой комнаты
        self._roomControlViewModel = StateObject(wrappedValue: RoomControlViewModel.createIsolated())
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                // Основной контрол с данными из ViewModel
                ControlView(
                    isOn: $roomControlViewModel.isOn,
                    baseColor: roomControlViewModel.defaultWarmColor,
                    bulbName: room.name,
                    bulbType: roomControlViewModel.getRoomType(),
                    roomName: "\(roomControlViewModel.getLightCount()) lights",
                    bulbIcon: roomControlViewModel.getRoomIcon(),
                    roomIcon: "",
                    onToggle: { newState in
                        // Переключаем все лампы в комнате
                        roomControlViewModel.setPower(newState)
                    },
                    onMenuTap: {
                        // TODO: Показать меню комнаты
                        print("🏠 Меню комнаты \(room.name)")
                    }
                )
                
                // Индикатор статуса комнаты
                HStack(spacing: 8) {
                    Circle()
                        .fill(roomControlViewModel.isRoomAvailable() ? Color.green.opacity(0) : Color.red.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text(roomControlViewModel.isRoomAvailable() ? "" : "Пустая")
                        .font(Font.custom("DMSans-Medium", size: 11))
                        .foregroundStyle(roomControlViewModel.isRoomAvailable() ? Color.green.opacity(0.9) : Color.red.opacity(0.8))
                        .textCase(.uppercase)
                }
                .adaptiveOffset(x: -10, y: -38)
            }
            
            // Слайдер яркости для всех ламп в комнате
            CustomSlider(
                percent: $roomControlViewModel.brightness,
                color: roomControlViewModel.defaultWarmColor,
                onChange: { value in
                    // Используем метод ViewModel для throttled обновлений всех ламп
                    roomControlViewModel.setBrightnessThrottled(value)
                },
                onCommit: { value in
                    // Используем метод ViewModel для финального коммита всех ламп
                    roomControlViewModel.commitBrightness(value)
                }
            )
            .padding(.leading, 10)
        }
        .onAppear {
            // Конфигурируем ViewModel с сервисами из appViewModel
            let lightService = LightControlService(appViewModel: appViewModel)
            let roomService = RoomService()
            
            roomControlViewModel.configure(
                with: lightService,
                roomService: roomService,
                room: room
            )
        }
        .onChange(of: room) { newRoom in
            // Обновляем ViewModel при изменении комнаты
            roomControlViewModel.setCurrentRoom(newRoom)
        }
    }
}

#Preview {
    let mockRoom = RoomEntity(
        id: "room_mock_01",
        name: "Living Room",
        type: .livingRoom,
        iconName: "tr1",
        lightIds: ["light1", "light2", "light3"],
        isActive: true,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    RoomControl(room: mockRoom)
        .environmentObject(AppViewModel())
        .environmentObject(NavigationManager.shared)
}
