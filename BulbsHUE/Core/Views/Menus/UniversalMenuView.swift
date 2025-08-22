//
//  UniversalMenuView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 12/31/25.
//

import SwiftUI

/// Универсальное меню настроек для ламп и комнат
/// Этот компонент обеспечивает единообразный интерфейс меню для разных типов элементов
struct UniversalMenuView: View {
    @EnvironmentObject var nav: NavigationManager
    
    /// Состояние для управления переходом к экрану переименования
    @State private var showRenameView: Bool = false
    /// Состояние для отображения экрана выбора типа
    @State private var showTypeSelection: Bool = false
    /// Состояние для хранения нового имени
    @State private var newName: String = ""
    
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
            
            // Кнопка закрытия
            DismissButton {
                nav.hideMenuView()
            }
            .adaptiveOffset(x: 130, y: -290)
            
            // Карточка элемента
            createItemCard()
            
            // Основное меню, экран переименования или выбор типа
            if showTypeSelection {
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
        switch itemData {
        case .bulb(let title, let subtitle, let icon, let baseColor, let bottomText):
            MenuItemCard(
                bulbTitle: title,
                subtitle: subtitle,
                icon: icon,
                baseColor: baseColor,
                bottomText: bottomText
            )
        case .room(let title, let subtitle, let bulbCount, let baseColor):
            MenuItemCard(
                roomTitle: title,
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
                    action: reorganizeAction
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
            
            // Поле ввода (пока текстовое поле, в реальной реализации будет TextField)
            ZStack {
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 332, height: 64)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .cornerRadius(15)
                    .opacity(0.1)
                
                Text(newName.isEmpty ? "\(menuConfig.itemTypeName) name" : newName)
                    .font(Font.custom("DMSans-Regular", size: 14))
                    .kerning(2.8)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
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
                menuConfig.renameAction?(newName)
                withAnimation(.easeInOut(duration: 0.3)) {
                    showRenameView = false
                }
            }
            .adaptiveOffset(y: 211)
        }
        .textCase(.uppercase)
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
                    onSave: { typeName, iconName in
                        print("🏠 Saving room type: \(typeName), icon: \(iconName)")
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
    case room(title: String, subtitle: String, bulbCount: Int, baseColor: Color)
    
    var title: String {
        switch self {
        case .bulb(let title, _, _, _, _), .room(let title, _, _, _):
            return title
        }
    }
    
    var baseColor: Color {
        switch self {
        case .bulb(_, _, _, let baseColor, _), .room(_, _, _, let baseColor):
            return baseColor
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
    .environmentObject(NavigationManager.shared)
}

#Preview("Room Menu") {
    UniversalMenuView(
        itemData: .room(
            title: "ROOM NAME",
            subtitle: "ROOM TYPE",
            bulbCount: 5,
            baseColor: .cyan
        ),
        menuConfig: .forRoom(
            onChangeType: { print("Change room type") },
            onRename: { newName in print("Rename room to: \(newName)") },
            onReorganize: { print("Reorganize room") },
            onDelete: { print("Delete room") }
        )
    )
    .environmentObject(NavigationManager.shared)
}
