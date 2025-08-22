//
//  MenuItemCard.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 12/31/25.
//

import SwiftUI

/// Универсальная карточка элемента для меню (лампы или комнаты)
/// Этот компонент создан для переиспользования в меню настроек ламп и комнат
struct MenuItemCard: View {
    /// Название элемента (название лампы или комнаты)
    let title: String
    /// Тип элемента (тип лампы или тип комнаты)
    let subtitle: String
    /// Базовый цвет для фона компонента
    let baseColor: Color
    /// Контент в верхней части карточки (иконка или количество ламп)
    let topContent: AnyView
    /// Текст в нижней части карточки (статус подключения или количество ламп)
    let bottomText: String
    
    /// Инициализатор для лампы с иконкой
    /// - Parameters:
    ///   - title: Название лампы
    ///   - subtitle: Тип лампы
    ///   - icon: Название иконки лампы
    ///   - baseColor: Цвет фона карточки
    ///   - bottomText: Текст статуса (например, "no room")
    init(bulbTitle title: String, 
         subtitle: String, 
         icon: String, 
         baseColor: Color, 
         bottomText: String) {
        self.title = title
        self.subtitle = subtitle
        self.baseColor = baseColor
        self.bottomText = bottomText
        // Создаем иконку лампы
        self.topContent = AnyView(
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(baseColor.preferredForeground)
                .adaptiveFrame(width: 32, height: 32)
                .adaptiveOffset(y: -42)
        )
    }
    
    /// Инициализатор для комнаты с количеством ламп
    /// - Parameters:
    ///   - title: Название комнаты
    ///   - subtitle: Тип комнаты
    ///   - bulbCount: Количество подключенных ламп
    ///   - baseColor: Цвет фона карточки
    init(roomTitle title: String, 
         subtitle: String, 
         bulbCount: Int, 
         baseColor: Color) {
        self.title = title
        self.subtitle = subtitle
        self.baseColor = baseColor
        self.bottomText = "\(bulbCount) bulbs"
        // Создаем отображение количества ламп в виде иконок
        self.topContent = AnyView(
            HStack(spacing: 6) {
                // Показываем максимум 5 иконок ламп
                ForEach(0..<min(bulbCount, 5), id: \.self) { _ in
                    Image("bulb")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(baseColor.preferredForeground)
                        .adaptiveFrame(width: 20, height: 20)
                }
            }
            .adaptiveOffset(y: -42)
        )
    }
    
    var body: some View {
        ZStack {
            // Фон карточки с градиентом
            BGItem(baseColor: baseColor)
                .adaptiveFrame(width: 278, height: 140)
            
            // Верхний контент (иконка или количество ламп)
            topContent
            
            // Название элемента
            Text(title)
                .font(Font.custom("DMSans-Medium", size: 20))
                .kerning(4.2)
                .foregroundColor(baseColor.preferredForeground)
                .textCase(.uppercase)
                .lineLimit(1)
                .adaptiveOffset(y: -5)
            
            // Подзаголовок (тип элемента)
            Text(subtitle)
                .font(Font.custom("DMSans-Light", size: 14))
                .kerning(2.8)
                .foregroundColor(baseColor.preferredForeground.opacity(0.9))
                .textCase(.uppercase)
                .lineLimit(1)
                .adaptiveOffset(y: 17)
            
            // Разделительная линия
            Rectangle()
                .fill(baseColor.preferredForeground)
                .adaptiveFrame(width: 212, height: 2)
                .opacity(0.2)
                .adaptiveOffset(y: 30)
            
            // Нижний текст (статус или количество ламп)
            Text(bottomText)
                .font(Font.custom("DMSans-Light", size: 15))
                .kerning(3)
                .foregroundColor(baseColor.preferredForeground.opacity(0.9))
                .textCase(.uppercase)
                .lineLimit(1)
                .adaptiveOffset(y: 48.5)
        }
        .adaptiveOffset(y: -173)
    }
}



#Preview("Bulb Card") {
    ZStack {
        Color.black
        MenuItemCard(
            bulbTitle: "BULB NAME", 
            subtitle: "BULB TYPE", 
            icon: "f2", 
            baseColor: .purple, 
            bottomText: "no room"
        )
    }
}

#Preview("Room Card") {
    ZStack {
        Color.black
        MenuItemCard(
            roomTitle: "ROOM NAME", 
            subtitle: "ROOM TYPE", 
            bulbCount: 5, 
            baseColor: .cyan
        )
    }
}

#Preview("Room Card - Few Bulbs") {
    ZStack {
        Color.black
        MenuItemCard(
            roomTitle: "BEDROOM", 
            subtitle: "LIVING", 
            bulbCount: 2, 
            baseColor: .orange
        )
    }
}
