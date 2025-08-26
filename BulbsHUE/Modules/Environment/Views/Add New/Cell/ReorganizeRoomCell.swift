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
    /// - Parameters:
    ///   - light: Данные лампочки для отображения
    ///   - onLightMoved: Callback при успешном переносе лампы
    init(light: Light? = nil, onLightMoved: (() -> Void)? = nil) {
        self.light = light
        self.onLightMoved = onLightMoved
    }
    
    /// Состояние показа/скрытия списка комнат
    @State private var showRoomsList = false
    
    /// Локальный список комнат для отображения
    @State private var rooms: [RoomEntity] = []
    
    /// Состояние загрузки
    @State private var isLoading = false
    
    /// Подписки Combine
    @State private var cancellables = Set<AnyCancellable>()
    
    /// Callback при успешном переносе лампы (для обновления UI)
    var onLightMoved: (() -> Void)?
    
    // MARK: - Computed Properties
    
    /// Вычисляет общую высоту области списка комнат в зависимости от количества комнат
    private var totalHeight: CGFloat {
        if showRoomsList {
            let roomCellHeight: CGFloat = 64  // Высота каждой комнаты (RoomManagementCell)
            let spacing: CGFloat = 8          // Расстояние между ячейками 
            let headerHeight: CGFloat = 60    // Высота заголовка "move bulb to"
            let padding: CGFloat = 30         // Отступы сверху и снизу
            
            let availableRooms = getAvailableRooms()
            
            if availableRooms.isEmpty && !isLoading {
                // Если доступных комнат нет - показываем минимальную высоту для сообщения
                return headerHeight + 60 + padding
            } else if isLoading {
                // Во время загрузки - высота для ProgressView
                return headerHeight + 60 + padding
            } else {
                // Рассчитываем высоту по количеству доступных комнат (максимум на 2 комнаты)
                let visibleRoomsCount = min(availableRooms.count, 2)
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
             
                    HStack {
                        HStack(spacing: 0) {
                            // Иконка типа лампочки
                            Image(light?.metadata.userSubtypeIcon ?? "lightBulb")
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: 32, height: 32)
                                .adaptiveFrame(width: 46)
                                .adaptiveOffset(x: 5)
                            // Реальные данные лампочки
                            VStack(alignment: .leading) {
                                Text(light?.metadata.name ?? "Unknovv")
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
                            .lineLimit(1)
                            .textCase(.uppercase)
                            .adaptiveOffset(x: 10)
                            .adaptiveFrame(width: 140)
                            
                        }
                        
                        .adaptiveFrame(width: 180)
                        
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
                        
                        .adaptiveOffset(x: 14)
                        
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
                                    // Показываем максимум 2 комнаты, исключая текущую комнату лампы
                                    let availableRooms = getAvailableRooms()
                                    ForEach(Array(availableRooms.prefix(2)), id: \.id) { room in
                                        RoomManagementCell(
                                            iconName: room.iconName,
                                            roomName: room.name, 
                                            roomType: room.type.displayName,
                                            onChevronTap: {
                                                // Перемещаем лампу в выбранную комнату
                                                moveLightToRoom(room)
                                            }
                                        )
                                    }
                                        
                                    
                                    // Показываем сообщение если доступных комнат нет
                                    
                                    if availableRooms.isEmpty && !isLoading {
                                        Text("Нет доступных комнат")
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
    
    /// Получает ID текущей комнаты для лампочки
    /// - Returns: ID комнаты или nil
    private func getCurrentRoomId() -> String? {
        guard let light = light else {
            return nil
        }
        
        // Ищем комнату, к которой принадлежит эта лампочка
        for room in rooms {
            if room.lightIds.contains(light.id) {
                return room.id
            }
        }
        
        return nil
    }
    
    /// Фильтрует комнаты, исключая текущую комнату лампы
    /// - Returns: Список доступных комнат для переноса
    private func getAvailableRooms() -> [RoomEntity] {
        guard let light = light else {
            return rooms
        }
        
        // Исключаем текущую комнату лампы из списка
        return rooms.filter { room in
            !room.lightIds.contains(light.id)
        }
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
    
    /// Перемещает лампу в выбранную комнату
    /// - Parameter targetRoom: Комната, в которую нужно переместить лампу
    private func moveLightToRoom(_ targetRoom: RoomEntity) {
        guard let light = light else {
            print("❌ Ошибка: Нет данных лампы для перемещения")
            return
        }
        
        isLoading = true
        
        // Получаем Use Case из DIContainer
        let moveLightUseCase = DIContainer.shared.moveLightBetweenRoomsUseCase
        
        // Создаем input для Use Case
        let input = MoveLightBetweenRoomsUseCase.Input(
            lightId: light.id,
            fromRoomId: getCurrentRoomId(), // Может быть nil если лампа не в комнате
            toRoomId: targetRoom.id
        )
        
        // Выполняем перенос лампы
        moveLightUseCase.execute(input)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    
                    switch completion {
                    case .finished:
                       
                        
                        // Скрываем список комнат после успешного переноса
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.showRoomsList = false
                        }
                        
                        // Перезагружаем список комнат для обновления состояния
                        self.loadRooms()
                        
                        // Вызываем callback для обновления UI в родительском View
                        self.onLightMoved?()
                        
                    case .failure(let error):
                        print("❌ Ошибка при перемещении лампы: \(error.localizedDescription)")
                        // TODO: Показать alert с ошибкой пользователю
                    }
                },
                receiveValue: { _ in
                    // Операция завершена успешно
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
