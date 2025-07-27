//
//  MenuIcon.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct MenuIcon: View {
    var body: some View {
        ZStack {
            // Верхняя линия (короткая)
            Capsule()
                .fill(.primColor)
                .adaptiveFrame(width: 11.64, height: 2.33)
                .adaptiveOffset(x: 0.01, y: -6.83)
            
            // Средняя линия (длинная)
            Capsule()
                .fill(.primColor)
                .adaptiveFrame(width: 17.45, height: 2.33)
                .adaptiveOffset(x: 0, y: -0.14)
            
            // Нижняя линия (короткая)
            Capsule()
                .fill(.primColor)
                .adaptiveFrame(width: 11.64, height: 2.33)
                .adaptiveOffset(x: 0.01, y: 6.55)
        }
        .frame(width: 18.91, height: 16)
    }
}

#Preview {
    MenuIcon()
}
