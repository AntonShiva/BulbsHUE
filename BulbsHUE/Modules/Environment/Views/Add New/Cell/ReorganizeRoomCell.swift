//
//  ReorganizeRoomCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/22/25.
//

import SwiftUI
import Combine

/// Ячейка для реорганизации лампы с показом списка доступных комнат
/// Позволяет пользователю переместить лампу в другую комнату
struct ReorganizeRoomCell: View {
    
    // MARK: - Environment Objects
    
    /// Единый источник данных приложения
    @EnvironmentObject var dataPersistenceService: DataPersistenceService
    
    // MARK: - Properties
    
    /// Данные лампочки для отображения
    let light: Light?
    
    /// Инициализатор с данными лампочки
    /// - Parameter light: Данные лампочки для отображения
    init(light: Light? = nil) {
        self.light = light
    }
    
    /// Состояние показа/скрытия списка комнат
    @State private var showRoomsList = false
    
    /// Локальный список комнат для отображения
    @State private var rooms: [RoomEntity] = []
    
    /// Состояние загрузки
    @State private var isLoading = false
    
    /// Подписки Combine
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Вычисляет общую высоту области списка комнат в зависимости от количества комнат
    private var totalHeight: CGFloat {
        if showRoomsList {
            let roomCellHeight: CGFloat = 64  // Высота каждой комнаты (RoomManagementCell)
            let spacing: CGFloat = 8          // Расстояние между ячейками 
            let headerHeight: CGFloat = 60    // Высота заголовка "move bulb to"
            let padding: CGFloat = 30         // Отступы сверху и снизу
            
            if rooms.isEmpty && !isLoading {
                // Если комнат нет - показываем минимальную высоту для сообщения "No rooms"
                return headerHeight + 60 + padding
            } else if isLoading {
                // Во время загрузки - высота для ProgressView
                return headerHeight + 60 + padding
            } else {
                // Рассчитываем высоту по количеству комнат (максимум на 2 комнаты)
                let visibleRoomsCount = min(rooms.count, 2)
                return headerHeight + (CGFloat(visibleRoomsCount) * roomCellHeight) + 
                       (CGFloat(max(visibleRoomsCount - 1, 0)) * spacing) + padding
            }
        } else {
            return 0 // Не показываем список
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Расширяемый фон
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 332, height: 64)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(15)
                .opacity(0.1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            
            VStack(spacing: 8) {
                // Основная ячейка (неизменная часть)
                ZStack {
                    HStack {
                        HStack(spacing: 0) {
                            // Иконка типа лампочки
                            Image(light?.metadata.userSubtypeIcon ?? "lightBulb")
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: 32, height: 32)
                                .adaptiveFrame(width: 66)
                            
                            // Реальные данные лампочки
                            VStack {
                                Text(light?.metadata.name ?? "Unknown Bulb")
                                    .font(Font.custom("DMSans-Regular", size: 14))
                                    .kerning(3)
                                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(getCurrentRoomName())
                                    .font(Font.custom("DM Sans", size: 12))
                                    .kerning(2.4)
                                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                    .opacity(0.4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .textCase(.uppercase)
                            .adaptiveOffset(x: 6)
                            
                        }
                        .adaptivePadding(.trailing, 10)
                        
                        HStack{
                            Button {
                                
                            } label: {
                                Image("Delete")
                                    .resizable()
                                    .scaledToFit()
                                    .adaptiveFrame(width: 24, height: 24)
                            }
                            .adaptiveFrame(width: 52)
                            .buttonStyle(.plain)
                            
                            Rectangle()
                                .fill(Color(red: 0.79, green: 1, blue: 1))
                                .adaptiveFrame(width: 1.5, height: 40)
                                .opacity(0.2)
                            
                            Button {
                                // Переключаем состояние показа списка комнат с анимацией
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showRoomsList.toggle()
                                }
                                
                                // Загружаем список комнат при первом показе
                                if showRoomsList && rooms.isEmpty {
                                    loadRooms()
                                }
                            } label: {
                                Image("ReorganizeRoom")
                                    .resizable()
                                    .scaledToFit()
                                    .adaptiveFrame(width: 22, height: 22)
                                    .adaptiveFrame(width: 52)
                            }
                            .buttonStyle(.plain)
                        }
                        .adaptiveFrame(width: 30)
                        
                        .adaptiveOffset(x: -50)
                        
                    }
                    
                }
                .adaptiveFrame(width: 332, height: 64)
                
                // Список комнат - показывается только при showRoomsList = true
                if showRoomsList {
                    // list of rooms
                    VStack{
                        ZStack{
                                                    Rectangle()
                            .foregroundColor(.clear)
                            .adaptiveFrame(width: 332, height: totalHeight)
                            .background(Color(red: 0.79, green: 1, blue: 1).opacity(0.1))
                            .cornerRadius(15)
                            .blur(radius: 2)
                            VStack(spacing: 15){
                                HStack{
                                    Image("ReorganizeRoom")
                                        .resizable()
                                        .scaledToFit()
                                        .adaptiveFrame(width: 22, height: 22)
                                        .adaptivePadding(.trailing, 8)
                                    
                                    Text("move bulb to")
                                        .font( Font.custom("DMSans-Light", size: 16))
                                        .kerning(2.72)
                                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                        .textCase(.uppercase)
                                }
                                
                                // Список комнат из единого источника данных
                                VStack(spacing: 8) {
                                    // Показываем максимум 2 комнаты
                                    ForEach(Array(rooms.prefix(2)), id: \.id) { room in
                                        RoomManagementCell(
                                            iconName: room.iconName,
                                            roomName: room.name, 
                                            roomType: room.type.displayName
                                        )
                                    }
                                        
                                    
                                    // Показываем сообщение если комнат нет
                                    if rooms.isEmpty && !isLoading {
                                        Text("No rooms")
                                            .font(Font.custom("DMSans-Light", size: 14))
                                            .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.6))
                                            .adaptivePadding(.vertical, 20)
                                    }
                                    
                                    // Показываем индикатор загрузки
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.79, green: 1, blue: 1)))
                                            .adaptivePadding(.vertical, 20)
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            }
        
        .onAppear {
            // Загружаем комнаты при первом появлении View
            if rooms.isEmpty {
                loadRooms()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Получает название текущей комнаты для лампочки
    /// - Returns: Название комнаты или "Не назначена"
    private func getCurrentRoomName() -> String {
        guard let light = light else {
            return "Не назначена"
        }
        
        // Ищем комнату, к которой принадлежит эта лампочка
        for room in rooms {
            if room.lightIds.contains(light.id) {
                return room.name
            }
        }
        
        return "Не назначена"
    }
    
    // MARK: - Private Methods
    
    /// Загружает список комнат из единого источника данных
    private func loadRooms() {
        isLoading = true
        
        // Используем DIContainer для получения UseCase
        let getRoomsUseCase = DIContainer.shared.getRoomsUseCase
        
        // GetRoomsUseCase возвращает Publisher, а не async метод
        getRoomsUseCase.execute(())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        print("Error loading rooms: \(error)")
                    }
                },
                receiveValue: { roomsList in
                    self.rooms = roomsList
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    ZStack{
        BG()
        ReorganizeRoomCell(light: nil)
    }
    .environmentObject(DataPersistenceService())
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2075-219&t=p1MiOXAQpotRB4uj-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
