//
//  AssignedRoomsListView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

/// Список созданных комнат в Environment
struct AssignedRoomsListView: View {
    // MARK: - Properties
    let rooms: [RoomEntity]
    let onRemoveRoom: (String) -> Void
    
    // MARK: - Environment Objects
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var nav: NavigationManager
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                // Верхний отступ для первого элемента
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 332, height: 64)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .cornerRadius(15)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .opacity(0)
                
                // Список комнат
                ForEach(rooms) { room in
                    // ✅ ИСПРАВЛЕНО: Используем правильный RoomControl с логикой управления
                    RoomControl(room: room)
                    .contextMenu {
                        // Контекстное меню для удаления комнаты
                        Button(role: .destructive) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onRemoveRoom(room.id)
                            }
                        } label: {
                            Label("Remove Room", systemImage: "trash")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .adaptiveFrame(height: 555)
    }
}

#Preview {
    let sampleRooms = [
        RoomEntity(
            id: "room1",
            name: "Living Room",
            type: .livingRoom,
            iconName: "tr1",
            lightIds: ["light1", "light2", "light3"],
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        RoomEntity(
            id: "room2",
            name: "Kitchen",
            type: .kitchen,
            iconName: "tr2",
            lightIds: ["light4", "light5"],
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        RoomEntity(
            id: "room3",
            name: "Bedroom",
            type: .bedroom,
            iconName: "tr4",
            lightIds: ["light6"],
            isActive: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
    
    AssignedRoomsListView(
        rooms: sampleRooms,
        onRemoveRoom: { roomId in
            print("Remove room: \(roomId)")
        }
    )
    .environmentObject(NavigationManager.shared)
    .environmentObject(AppViewModel())
}
