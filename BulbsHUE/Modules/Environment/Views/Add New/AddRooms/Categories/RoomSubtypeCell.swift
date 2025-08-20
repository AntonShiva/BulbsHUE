//
//  RoomSubtypeCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 18.08.2025.
//

import SwiftUI

// MARK: - Ячейка подтипа комнаты
struct RoomSubtypeCell: View {
    let subtype: RoomSubtype
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Иконка подтипа - автоматически подставляется правильная иконка из Assets
            Image(subtype.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: 40) // Фиксированная область для иконки
            
            // Название подтипа - берется из модели данных
            Text(subtype.name)
                .font(Font.custom("DMSans-Light", size: 12))
                .kerning(2.4)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Индикатор выбора - показывает реальное состояние выбора
            SelectionIndicator(isSelected: isSelected)
        }
        .frame(width: 274, height: 28)
        .contentShape(Rectangle()) // Вся область ячейки кликабельна
        .onTapGesture {
            onSelect() // Вызывает callback для переключения состояния
        }
    }
}

#Preview {
    ZStack {
        BG()
        RoomSubtypeCell(
            subtype: RoomSubtype(name: "LIVING ROOM", iconName: "tr1", roomType: .livingRoom),
            isSelected: true
        ) {
            print("Room subtype selected")
        }
    }
}
