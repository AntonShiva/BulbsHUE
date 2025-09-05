//
//  UniversalTypeSelectionView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 12/31/25.
//

import SwiftUI

/// Универсальное View для выбора подтипов ламп и комнат
/// Использует существующую архитектуру TupeCell и TypeManager
struct UniversalTypeSelectionView: View {
    @Environment(NavigationManager.self) private var nav
    
    /// Конфигурация для выбора типа
    let config: TypeSelectionConfig
    /// Callback для сохранения выбранного типа
    let onSave: (String, String) -> Void
    /// Callback для отмены
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Основной фон
            UnevenRoundedRectangle(
                topLeadingRadius: 35,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 35
            )
            .fill(Color(red: 0.02, green: 0.09, blue: 0.13))
            .adaptiveFrame(width: 375, height: 785)
            .adaptiveOffset(y: 20)
            
            // Контейнер для содержимого
            VStack(spacing: 0) {
                // Верхняя часть с заголовком и выбранным типом
                createHeaderSection()
                
                // Скроллируемая область с типами
                createScrollableTypeList()
                
                // Кнопка сохранения
                createSaveButton()
            }
            .adaptiveFrame(width: 375, height: 785)
            .adaptiveOffset(y: 20)
        }
    }
    
    // MARK: - Private Methods
    
    /// Создает секцию заголовка
    @ViewBuilder
    private func createHeaderSection() -> some View {
        VStack(spacing: 20) {
            // Кнопка закрытия
            HStack {
                Spacer()
                DismissButton {
                    onCancel()
                }
                .adaptiveOffset(x: -30, y: 10)
            }
            
            // Заголовок
            Text(config.title)
                .font(Font.custom("DMSans-Medium", size: 20))
                .kerning(4.2)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .textCase(.uppercase)
                .padding(.top, 20)
            
            // Отображение выбранного типа
            ZStack {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 332, height: 64)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .cornerRadius(15)
                    .opacity(0.1)
                
                Text(config.getSelectedTypeName())
                    .font(Font.custom("DMSans-Light", size: 14))
                    .kerning(2.8)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .textCase(.uppercase)
            }
            .padding(.top, 20)
            
            Text(config.subtitle)
                .font(Font.custom("DM Sans", size: 12).weight(.light))
                .kerning(2.4)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .textCase(.uppercase)
                .padding(.top, 15)
        }
        .frame(height: 230)
        .adaptiveOffset(y: -10)
    }
    
    /// Создает скроллируемый список типов
    @ViewBuilder
    private func createScrollableTypeList() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                config.createTypeList()
            }
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .frame(maxHeight: 475)
        .clipped()
    }
    
    /// Создает кнопку сохранения
    @ViewBuilder
    private func createSaveButton() -> some View {
        VStack {
            Spacer()
            
            if config.hasSelection() {
                CostumButton(
                    text: config.saveButtonText,
                    width: 230,
                    height: 210,
                    image: "BGCustomButton"
                ) {
                    if let (name, icon) = config.getSelectedTypeData() {
                        onSave(name, icon)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(height: 100)
    }
}

// MARK: - Configuration Protocol

/// Протокол конфигурации для выбора типов
protocol TypeSelectionConfig {
    /// Заголовок экрана
    var title: String { get }
    /// Подзаголовок
    var subtitle: String { get }
    /// Текст кнопки сохранения
    var saveButtonText: String { get }
    
    /// Возвращает название выбранного типа или placeholder
    func getSelectedTypeName() -> String
    /// Проверяет наличие выбора
    func hasSelection() -> Bool
    /// Возвращает данные выбранного типа (имя и иконка)
    func getSelectedTypeData() -> (String, String)?
    /// Создает список типов для выбора
    func createTypeList() -> AnyView
    /// Сбрасывает выбор
    func clearSelection()
}



// MARK: - Specialized Views

/// Специализированный экран выбора типов ламп
struct BulbTypeSelectionSheet: View {
    @State private var typeManager = BulbTypeManager()
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        UniversalTypeSelectionView(
            config: BulbTypeConfig(typeManager: typeManager),
            onSave: onSave,
            onCancel: onCancel
        )
        .onAppear {
            // Сбрасываем выбор при каждом открытии
            typeManager.clearSelection()
        }
    }
}

/// Специализированный экран выбора типов комнат
struct RoomTypeSelectionSheet: View {
    @State private var categoryManager = RoomCategoryManager()
    let onSave: (String, String, RoomSubType) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        UniversalTypeSelectionView(
            config: RoomTypeConfig(categoryManager: categoryManager),
            onSave: { typeName, iconName in
                // Получаем выбранный подтип с RoomSubType
                if let selectedSubtype = categoryManager.getSelectedSubtype() {
                    onSave(typeName, iconName, selectedSubtype.roomType)
                }
            },
            onCancel: onCancel
        )
        .onAppear {
            // Сбрасываем выбор при каждом открытии
            categoryManager.clearSelection()
        }
    }
}

// MARK: - Updated Configurations

struct BulbTypeConfig: TypeSelectionConfig {
    let typeManager: BulbTypeManager
    
    var title: String { "change bulb type" }
    var subtitle: String { "please select bulb type" }
    var saveButtonText: String { "save type" }
    
    func getSelectedTypeName() -> String {
        if let selected = typeManager.getSelectedSubtype() {
            return selected.name
        } else {
            return "Select type"
        }
    }
    
    func hasSelection() -> Bool {
        return typeManager.hasSelection
    }
    
    func getSelectedTypeData() -> (String, String)? {
        guard let selected = typeManager.getSelectedSubtype() else { return nil }
        return (selected.name, selected.iconName)
    }
    
    func createTypeList() -> AnyView {
        AnyView(
            ForEach(typeManager.bulbTypes, id: \.id) { bulbType in
                TupeCell(
                    bulbType: bulbType,
                    typeManager: typeManager,
                    iconWidth: 32,
                    iconHeight: 32
                )
            }
        )
    }
    
    func clearSelection() {
        typeManager.clearSelection()
    }
}

struct RoomTypeConfig: TypeSelectionConfig {
    let categoryManager: RoomCategoryManager
    
    var title: String { "change room type" }
    var subtitle: String { "please select room type" }
    var saveButtonText: String { "save type" }
    
    func getSelectedTypeName() -> String {
        if let selected = categoryManager.getSelectedSubtype() {
            return selected.name
        } else {
            return "Select type"
        }
    }
    
    func hasSelection() -> Bool {
        return categoryManager.hasSelection
    }
    
    func getSelectedTypeData() -> (String, String)? {
        guard let selected = categoryManager.getSelectedSubtype() else { return nil }
        return (selected.name, selected.iconName)
    }
    
    func createTypeList() -> AnyView {
        AnyView(
            ForEach(categoryManager.roomCategories, id: \.id) { roomCategory in
                TupeCell(
                    roomCategory: roomCategory,
                    categoryManager: categoryManager,
                    iconWidth: 32,
                    iconHeight: 32
                )
            }
        )
    }
    
    func clearSelection() {
        categoryManager.clearSelection()
    }
}

#Preview("Bulb Type Selection") {
    BulbTypeSelectionSheet(
        onSave: { name, icon in
            print("Save bulb type: \(name), icon: \(icon)")
        },
        onCancel: {
            print("Cancel bulb type selection")
        }
    )
    .environment(NavigationManager.shared)
}

#Preview("Room Type Selection") {
    RoomTypeSelectionSheet(
        onSave: { name, icon, roomType in
            print("Save room type: \(name), icon: \(icon), type: \(roomType)")
        },
        onCancel: {
            print("Cancel room type selection")
        }
    )
    .environment(NavigationManager.shared)
}
