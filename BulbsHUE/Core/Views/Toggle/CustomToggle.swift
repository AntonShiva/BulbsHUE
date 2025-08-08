//
//  CustomToggle.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/8/25.
//
import SwiftUI

struct CustomToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        ZStack {
            // Фон переключателя
            RoundedRectangle(cornerRadius: 100)
                .fill(Color.black.opacity(0.42))
                .adaptiveFrame(width: 72, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                )

            // Круглый переключатель
            Circle()
                .fill(Color.white)
                .adaptiveFrame(width: 28, height: 28)
                .adaptiveOffset(x: isOn ? 51 - 36 : -51 + 36) // смещение по состоянию
                .animation(.easeInOut(duration: 0.2), value: isOn)
        }
        .adaptiveFrame(width: 72, height: 40)
        .onTapGesture {
            isOn.toggle()
        }
    }
}

#Preview {
    CustomToggle(isOn: .constant(true))
}
