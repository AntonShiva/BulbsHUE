//
//  LampSubtypeCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 05.08.2025.
//

import SwiftUI

// MARK: - Ячейка подтипа лампы
struct LampSubtypeCell: View {
    let subtype: LampSubtype
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Иконка подтипа
            Image(subtype.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: 40) // Фиксированная область для иконки
            
            // Название подтипа
            Text(subtype.name)
                .font(Font.custom("DM Sans", size: 12))
                .kerning(2.4)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Индикатор выбора
            SelectionIndicator(isSelected: subtype.isSelected)
        }
        .frame(width: 274, height: 28)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    ZStack {
        BG()
        LampSubtypeCell(subtype: LampSubtype(name: "Floor Type 1", iconName: "f1", isSelected: true)){
            
        }
    }
}
