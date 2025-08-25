//
//  EditItemCardRoom.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/25/25.
//

import SwiftUI

struct EditItemCardRoom: View {
    /// Название элемента (название лампы или комнаты)
    let title: String

    /// Базовый цвет для фона компонента
    let baseColor: Color
    /// Контент в верхней части карточки (иконка или количество ламп)
    let topContent: AnyView
    /// Текст в нижней части карточки (статус подключения или количество ламп)
    let bottomText: String
    init(roomTitle title: String,
        
         bulbCount: Int,
         baseColor: Color) {
        self.title = title
       
        self.baseColor = baseColor
        self.bottomText = "\(bulbCount) bulbs"
        // Создаем отображение количества ламп в виде иконок
        self.topContent = AnyView(
            HStack(spacing: 1) {
                // Показываем максимум 5 иконок ламп
                ForEach(0..<min(bulbCount, 5), id: \.self) { _ in
                    Image("bulb")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(baseColor.preferredForeground)
                        .adaptiveFrame(width: 32, height: 32)
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
                .adaptiveOffset(y: 12)
            // Название элемента
            Text(title.capitalizingFirstLetter())
                .font(Font.custom("DMSans-SemiBold", size: 33))
               
                .foregroundColor(baseColor.preferredForeground)
                .lineLimit(1)
                .adaptiveOffset(y: 18)
            
            // Нижний текст (статус или количество ламп)
            Text(bottomText)
                .font(Font.custom("DMSans-Light", size: 15))
                .kerning(3)
                .foregroundColor(baseColor.preferredForeground.opacity(0.9))
                .textCase(.uppercase)
                .lineLimit(1)
                .adaptiveOffset(y: 48.5)
        }
//        .adaptiveOffset(y: -173)
    }
}

#Preview("Room Card") {
    ZStack {
        Color.black
        EditItemCardRoom(
            roomTitle: "Room name",
            
            bulbCount: 5,
            baseColor: .cyan
        )
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2075-219&t=sC3aD0A4Ffr835aT-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}



extension String {
    func capitalizingFirstLetter() -> String {
        // Проверяем, не пустая ли строка
        if self.isEmpty { return "" }
        // Берем первый символ, делаем его заглавным,
        // а остальную часть строки делаем строчной
        return self.prefix(1).uppercased() + self.dropFirst().lowercased()
    }
}
