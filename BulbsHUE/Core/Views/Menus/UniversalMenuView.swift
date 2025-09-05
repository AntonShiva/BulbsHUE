//
//  UniversalMenuView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 12/31/25.
//

import SwiftUI
import Combine

/// Универсальное меню настроек для ламп и комнат
/// Этот компонент обеспечивает единообразный интерфейс меню для разных типов элементов
struct UniversalMenuView: View {
    @Environment(NavigationManager.self) private var nav
    @Environment(DataPersistenceService.self) private var dataPersistenceService
    
    /// Состояние для управления переходом к экрану переименования
    @State private var showRenameView: Bool = false
    /// Состояние для отображения экрана выбора типа
    @State private var showTypeSelection: Bool = false
    /// Состояние для режима реорганизации (показ списка ламп для переноса)
    @State private var showReorganizeMode: Bool = false
    /// Состояние для хранения нового имени
    @State private var newName: String = ""
    /// Лампочки текущей комнаты для режима реорганизации
    @State private var roomLights: [Light] = []

    
    /// Статическая переменная для хранения подписок Combine
    private static var cancellables = Set<AnyCancellable>()
    
    /// Данные об элементе (лампа или комната)
    let itemData: MenuItemData
    /// Конфигурация меню (какие кнопки показывать и их действия)
    let menuConfig: MenuConfiguration
    

    
    var body: some View {
        ZStack {
            // Фон меню
            UnevenRoundedRectangle(
                topLeadingRadius: 35,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 35
            )
            .fill(Color(red: 0.02, green: 0.09, blue: 0.13))
            .adaptiveFrame(width: 375, height: 678)
            
            Text("room management")
              .font(
                Font.custom("DM Sans", size: 16))
              .kerning(2.72)
              .foregroundColor(.white)
              .textCase(.uppercase)
              .adaptiveOffset(y: -290)
            // Кнопка закрытия
            DismissButton {
                nav.hideMenuView()
            }
            .adaptiveOffset(x: 140, y: -290)
            
            // Карточка элемента или специальная карточка для режима реорганизации
            if showReorganizeMode {
                createReorganizeCard()
                    .adaptiveOffset(y: -173)
            } else {
                createItemCard()
            }
        
            // Основное меню, экран переименования, выбор типа или режим реорганизации
            if showReorganizeMode {
                createReorganizeView()
                    .adaptiveOffset(y: 30)
            } else if showTypeSelection {
                createTypeSelectionView()
                    .adaptiveOffset(y: -70)
            } else if !showRenameView {
                createMainMenu()
            } else {
                createRenameView()
            }
        }
        .adaptiveOffset(y: 67)
        .onAppear {
            // Инициализируем поле ввода текущим именем
            newName = itemData.title
        }
    }
    
    // MARK: - Private Methods
    
    /// Создает карточку элемента (лампы или комнаты)
    @ViewBuilder
    private func createItemCard() -> some View {
        // Используем реактивные данные из NavigationManager
        switch itemData {
        case .bulb(_, let subtitle, let icon, let baseColor, let bottomText):
            // Для лампы берем актуальное имя из selectedLightForMenu
            let currentTitle = nav.selectedLightForMenu?.metadata.name ?? "Unknown Light"
            MenuItemCard(
                bulbTitle: currentTitle,
                subtitle: subtitle,
                icon: icon,
                baseColor: baseColor,
                bottomText: bottomText
            )
        case .room(_, let subtitle, let bulbCount, let baseColor, _):
            // Для комнаты берем актуальное имя из selectedRoomForMenu
            let currentTitle = nav.selectedRoomForMenu?.name ?? "Unknown Room"
            MenuItemCard(
                roomTitle: currentTitle,
                subtitle: subtitle,
                bulbCount: bulbCount,
                baseColor: baseColor
            )
        }
    }
    
    /// Создает основное меню с кнопками действий
    @ViewBuilder
    private func createMainMenu() -> some View {
        VStack(spacing: 9.5) {
            // Кнопка "Change type" для ламп и комнат
            if menuConfig.changeTypeAction != nil {
                createMenuButton(
                    icon: menuConfig.changeTypeIcon ?? "bulb",
                    title: "Change type",
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTypeSelection = true
                        }
                    }
                )
                
                createSeparator()
            }
            
            // Кнопка "Rename"
            createMenuButton(
                icon: "Rename",
                title: "Rename",
                action: {
                    // Инициализируем поле ввода текущим именем перед показом
                    initializeCurrentName()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showRenameView = true
                    }
                }
            )
            
            createSeparator()
            
            // Кнопка "Reorganize"
            if let reorganizeAction = menuConfig.reorganizeAction {
                createMenuButton(
                    icon: "Reorganize",
                    title: "Reorganize",
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showReorganizeMode = true
                        }
                        reorganizeAction()
                    }
                )
                
                createSeparator()
            }
            
            // Кнопка удаления
            createMenuButton(
                icon: "Delete",
                title: menuConfig.deleteTitle,
                action: menuConfig.deleteAction
            )
        }
        .adaptiveFrame(width: 292, height: 280)
        .adaptiveOffset(y: 106)
    }
    
    /// Создает экран переименования
    @ViewBuilder
    private func createRenameView() -> some View {
        ZStack {
            // Заголовок
            Text("your new \(menuConfig.itemTypeName) name")
                .font(Font.custom("DMSans-Regular", size: 14))
                .kerning(2.8)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .adaptiveOffset(y: -20)
            
            // Поле ввода с TextField
            ZStack {
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 332, height: 64)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .cornerRadius(15)
                    .opacity(0.1)
                
                TextField("\(menuConfig.itemTypeName) name", text: $newName)
                    .font(Font.custom("DMSans-Regular", size: 14))
                    .kerning(2.8)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .textFieldStyle(PlainTextFieldStyle())
                    .multilineTextAlignment(.center)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16)
            }
            .adaptiveOffset(y: 34)
            
            // Кнопка сохранения
            CustomButtonAdaptive(
                text: "rename",
                width: 390,
                height: 266,
                image: "BGRename",
                offsetX: 0,
                offsetY: 17
            ) {
                saveNewName()
                withAnimation(.easeInOut(duration: 0.3)) {
                    showRenameView = false
                }
            }
            .adaptiveOffset(y: 211)
        }
        .textCase(.uppercase)
    }
    
    /// Инициализирует поле ввода текущим именем элемента
    private func initializeCurrentName() {
        switch itemData {
        case .bulb(let title, _, _, _, _):
            newName = title
        case .room(let title, _, _, _, _):
            newName = title
        }
    }
    
    /// Сохраняет новое имя через соответствующий Use Case
    private func saveNewName() {
        // Проверяем, что имя не пустое
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Пустое имя, сохранение отменено")
            return
        }
        
        switch itemData {
        case .bulb(_, _, _, _, _):
            saveNewLightName()
        case .room(_, _, _, _, let roomId):
            saveNewRoomName(roomId: roomId)
        }
    }
    
    /// Сохраняет новое имя лампы
    private func saveNewLightName() {
        guard let currentLight = nav.selectedLightForMenu else {
            print("❌ Не найдена текущая лампа для переименования")
            return
        }
        
        let updateUseCase = DIContainer.shared.updateLightNameUseCase
        let input = UpdateLightNameUseCase.Input(
            lightId: currentLight.id,
            newName: newName
        )
        
        updateUseCase.execute(input)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("✅ Имя лампы успешно обновлено в базе данных: \(self.newName)")
                        
                        // Обновляем через NavigationManager (следуя современным SwiftUI паттернам)
                        self.nav.updateLightName(lightId: currentLight.id, newName: self.newName)
                        
                    case .failure(let error):
                        print("❌ Ошибка при обновлении имени лампы: \(error.localizedDescription)")
                    }
                },
                receiveValue: { _ in
                    // Операция завершена успешно
                }
            )
            .store(in: &Self.cancellables)
    }
    
    /// Сохраняет новое имя комнаты
    private func saveNewRoomName(roomId: String) {
        let updateUseCase = DIContainer.shared.updateRoomNameUseCase
        let input = UpdateRoomNameUseCase.Input(
            roomId: roomId,
            newName: newName
        )
        
        updateUseCase.execute(input)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("✅ Имя комнаты успешно обновлено в базе данных: \(self.newName)")
                        
                        // Обновляем через NavigationManager (следуя современным SwiftUI паттернам)
                        self.nav.updateRoomName(roomId: roomId, newName: self.newName)
                        
                        // 3. Принудительно обновляем реактивные стримы в DataPersistenceService
                        // Repository автоматически обновит стримы после изменения данных
                        
                    case .failure(let error):
                        print("❌ Ошибка при обновлении имени комнаты: \(error.localizedDescription)")
                    }
                },
                receiveValue: { _ in
                    // Операция завершена успешно
                }
            )
            .store(in: &Self.cancellables)
    }
    

    
    /// Создает экран выбора типа
    @ViewBuilder
    private func createTypeSelectionView() -> some View {
        ZStack {
            switch itemData {
            case .bulb:
                BulbTypeSelectionSheet(
                    onSave: { typeName, iconName in
                        print("🔄 Saving bulb type: \(typeName), icon: \(iconName)")
                        menuConfig.onTypeChanged?(typeName, iconName)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTypeSelection = false
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTypeSelection = false
                        }
                    }
                )
            case .room:
                RoomTypeSelectionSheet(
                    onSave: { typeName, iconName, roomSubType in
                        print("🏠 Saving room type: \(typeName), icon: \(iconName), type: \(roomSubType)")
                        
                        // Обновляем selectedRoomForMenu с новыми данными
                        if let currentRoom = nav.selectedRoomForMenu {
                            
                            let updatedRoom = RoomEntity(
                                id: currentRoom.id,
                                name: currentRoom.name,
                                type: roomSubType,
                                subtypeName: typeName, // ✅ Сохраняем оригинальное название
                                iconName: iconName,
                                lightIds: currentRoom.lightIds,
                                isActive: currentRoom.isActive,
                                createdAt: currentRoom.createdAt,
                                updatedAt: Date()
                            )
                            
                                                    // Обновляем NavigationManager с новыми данными
                        nav.selectedRoomForMenu = updatedRoom
                        
                        // Сохраняем изменения в базе данных через Use Case
                        let updateRoomUseCase = DIContainer.shared.updateRoomUseCase
                        let input = UpdateRoomUseCase.Input(room: updatedRoom)
                        
                        updateRoomUseCase.execute(input)
                            .receive(on: DispatchQueue.main)
                            .sink(
                                receiveCompletion: { completion in
                                    switch completion {
                                    case .finished:
                                        print("✅ Тип комнаты успешно обновлен: \(typeName)")
                                    case .failure(let error):
                                        print("❌ Ошибка при обновлении типа комнаты: \(error.localizedDescription)")
                                    }
                                },
                                receiveValue: { _ in
                                    // Операция завершена успешно
                                }
                            )
                            .store(in: &Self.cancellables)
                        }
                        
                        menuConfig.onTypeChanged?(typeName, iconName)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTypeSelection = false
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTypeSelection = false
                        }
                    }
                )
            }
        }
    }
    
    /// Создает карточку для режима реорганизации
    @ViewBuilder
    private func createReorganizeCard() -> some View {
        switch itemData {
        case .room(let title, let subtitle, let bulbCount, let baseColor, _):
            EditItemCardRoom(
                roomTitle: title,
               bulbCount: bulbCount,
                baseColor: baseColor
            )
           
        default:
            // Для ламп используем обычную карточку
            createItemCard()
        }
    }
    
    /// Создает вид режима реорганизации с списком ламп
    @ViewBuilder
    private func createReorganizeView() -> some View {
        // Основное меню, экран переименования, выбор типа или режим реорганизации
        VStack(spacing: 12) {
            // Список ламп в комнате
            ScrollView {
                LazyVStack(spacing: 8) {
                    if roomLights.isEmpty {
                        // Показываем сообщение если в комнате нет ламп
                        VStack(spacing: 16) {
                            Text("В комнате нет ламп")
                                .font(Font.custom("DMSans-Medium", size: 16))
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.6))
                            
                            Text("Добавьте лампы в эту комнату")
                                .font(Font.custom("DMSans-Light", size: 14))
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.4))
                        }
                        .adaptivePadding(.vertical, 40)
                    } else {
                        // Показываем реальные лампы комнаты
                        ForEach(roomLights, id: \.id) { light in
                            ReorganizeRoomCell(
                                light: light,
                                onLightMoved: {
                                    // Перезагружаем лампы комнаты после переноса
                                    loadRoomLights()
                                }
                            )
                        }
                    }
                }
            }
        }
        .adaptiveOffset(y: 300)
        .onAppear {
            loadRoomLights()
        }
        .onChange(of: itemData.roomId) { oldValue, newValue in
            if oldValue != newValue {
                loadRoomLights()
            }
        }
    }
    
    /// Загружает лампочки для текущей комнаты
    private func loadRoomLights() {
        guard let roomId = itemData.roomId else {
            roomLights = []
            return
        }
        
        // Загружаем лампочки комнаты из DataPersistenceService
        Task { @MainActor in
            roomLights = dataPersistenceService.fetchLightsForRoom(roomId: roomId)
        }
    }
    
    /// Создает кнопку меню
    @ViewBuilder
    private func createMenuButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 43) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .adaptiveFrame(width: 40, height: 40)
                
                Text(title)
                    .font(Font.custom("InstrumentSans-Medium", size: 20))
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                
                Spacer()
            }
            .padding(.horizontal, 13)
            .adaptiveFrame(height: 60)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// Создает разделитель между кнопками
    @ViewBuilder
    private func createSeparator() -> some View {
        Rectangle()
            .fill(Color(red: 0.79, green: 1, blue: 1))
            .adaptiveFrame(height: 2)
            .opacity(0.2)
    }
}

// MARK: - Data Models

/// Данные об элементе меню
enum MenuItemData {
    case bulb(title: String, subtitle: String, icon: String, baseColor: Color, bottomText: String)
    case room(title: String, subtitle: String, bulbCount: Int, baseColor: Color, roomId: String)
    
    var title: String {
        switch self {
        case .bulb(let title, _, _, _, _), .room(let title, _, _, _, _):
            return title
        }
    }
    
    var baseColor: Color {
        switch self {
        case .bulb(_, _, _, let baseColor, _), .room(_, _, _, let baseColor, _):
            return baseColor
        }
    }
    
    /// Получить ID комнаты (если это комната)
    var roomId: String? {
        switch self {
        case .room(_, _, _, _, let roomId):
            return roomId
        case .bulb:
            return nil
        }
    }
}

/// Конфигурация меню (какие кнопки показывать и их действия)
struct MenuConfiguration {
    /// Название типа элемента (для UI текстов)
    let itemTypeName: String
    /// Заголовок кнопки удаления
    let deleteTitle: String
    /// Иконка для кнопки "Change type"
    let changeTypeIcon: String?
    
    /// Действие при нажатии "Change type"
    let changeTypeAction: (() -> Void)?
    /// Действие при смене типа (имя, иконка)
    let onTypeChanged: ((String, String) -> Void)?
    /// Действие при переименовании
    let renameAction: ((String) -> Void)?
    /// Действие при нажатии "Reorganize"
    let reorganizeAction: (() -> Void)?
    /// Действие при удалении
    let deleteAction: () -> Void
    
    /// Конфигурация для лампы
    static func forBulb(
        icon: String,
        onChangeType: (() -> Void)? = nil,
        onTypeChanged: ((String, String) -> Void)? = nil,
        onRename: ((String) -> Void)? = nil,
        onReorganize: (() -> Void)? = nil,
        onDelete: @escaping () -> Void
    ) -> MenuConfiguration {
        MenuConfiguration(
            itemTypeName: "bulb",
            deleteTitle: "Delete Bulb",
            changeTypeIcon: icon,
            changeTypeAction: onChangeType,
            onTypeChanged: onTypeChanged,
            renameAction: onRename,
            reorganizeAction: onReorganize,
            deleteAction: onDelete
        )
    }
    
    /// Конфигурация для комнаты
    static func forRoom(
        onChangeType: (() -> Void)? = nil,
        onTypeChanged: ((String, String) -> Void)? = nil,
        onRename: ((String) -> Void)? = nil,
        onReorganize: (() -> Void)? = nil,
        onDelete: @escaping () -> Void
    ) -> MenuConfiguration {
        MenuConfiguration(
            itemTypeName: "room",
            deleteTitle: "Delete Room",
            changeTypeIcon: "o1", // Иконка комнаты
            changeTypeAction: onChangeType,
            onTypeChanged: onTypeChanged,
            renameAction: onRename,
            reorganizeAction: onReorganize,
            deleteAction: onDelete
        )
    }
}



#Preview("Bulb Menu") {
    UniversalMenuView(
        itemData: .bulb(
            title: "BULB NAME",
            subtitle: "BULB TYPE",
            icon: "f2",
            baseColor: .purple,
            bottomText: "no room"
        ),
        menuConfig: .forBulb(
            icon: "f2",
            onChangeType: { print("Change bulb type") },
            onRename: { newName in print("Rename bulb to: \(newName)") },
            onReorganize: { print("Reorganize bulb") },
            onDelete: { print("Delete bulb") }
        )
    )
    .environment(NavigationManager.shared)
    .environment(DataPersistenceService())
}

#Preview("Room Menu") {
    UniversalMenuView(
        itemData: .room(
            title: "ROOM NAME",
            subtitle: "ROOM TYPE",
            bulbCount: 5,
            baseColor: .cyan,
            roomId: "preview_room_1"
        ),
        menuConfig: .forRoom(
            onChangeType: { print("Change room type") },
            onRename: { newName in print("Rename room to: \(newName)") },
            onReorganize: { print("Reorganize room - switching to reorganize mode") },
            onDelete: { print("Delete room") }
        )
    )
    .environment(NavigationManager.shared)
    .environment(DataPersistenceService())
}

#Preview("Room Menu - Reorganize Mode") {
    struct ReorganizeModePreview: View {
        @State private var showReorganizeMode = true
        
        var body: some View {
            UniversalMenuView(
                itemData: .room(
                    title: "LIVING ROOM",
                    subtitle: "RECREATION",
                    bulbCount: 3,
                    baseColor: .purple,
                    roomId: "preview_room_2"
                ),
                menuConfig: .forRoom(
                    onChangeType: { print("Change room type") },
                    onRename: { newName in print("Rename room to: \(newName)") },
                    onReorganize: { print("Reorganize room") },
                    onDelete: { print("Delete room") }
                )
            )
            .environment(NavigationManager.shared)
            .environment(DataPersistenceService())
        }
    }
    
    return ReorganizeModePreview()
}
