//
//  SelectionIndicator.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 05.08.2025.
//

import SwiftUI

// MARK: - Индикатор выбора
struct SelectionIndicator: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Внешний круг
            Circle()
                .fill(Color(red: 0.79, green: 1, blue: 1))
                .frame(width: 28, height: 28)
                .opacity(0.2)
            
            // Внутренний круг (показывается только если выбрано)
            if isSelected {
                Circle()
                    .fill(Color(red: 0.79, green: 1, blue: 1))
                    .frame(width: 18, height: 18)
                   
            }
        }
    }
}

#Preview {
    SelectionIndicator(isSelected: true)
}
