//
//  MenuItemRooms.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/22/25.
//

import SwiftUI

struct MenuItemRooms: View {
    let roomName: String
    /// Тип лампы (пользовательский подтип)
    let roomType: String
   /// Иконка лампы
    let icon: String
    /// Базовый цвет для фона компонента
    let baseColor: Color
    var body: some View {
        ZStack{
            BGItem(baseColor: baseColor)
                .adaptiveFrame(width: 278, height: 140)
            
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(baseColor.preferredForeground)
                .adaptiveFrame(width: 32, height: 32)
                .adaptiveOffset(y: -42)
            
            Text(roomName)
                .font(Font.custom("DMSans-Medium", size: 20))
                .kerning(4.2)
                .foregroundColor(baseColor.preferredForeground)
                .textCase(.uppercase)
                .lineLimit(1)
                .adaptiveOffset(y: -5)
            
            Text(roomType)
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
            
            Text("5 bulbs")
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

#Preview {
    MenuItemRooms(roomName: "Room name", roomType: "Тип", icon: "bulb", baseColor: .cyan)
}
