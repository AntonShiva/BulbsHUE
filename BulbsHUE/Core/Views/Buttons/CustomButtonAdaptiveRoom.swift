//
//  CustomButtonAdaptiveRoom.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

struct CustomButtonAdaptiveRoom: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    let image: String
    let cornerInset: CGFloat = 20 // Можно настроить под ваше изображение
    var offsetX: CGFloat
    var offsetY: CGFloat
    var isEnabled: Bool = true // Новое свойство для управления активностью кнопки
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Выполняем действие только если кнопка активна
            if isEnabled {
                action()
            }
        }) {
            ZStack {
                // Растягиваемый фон с изменением прозрачности в зависимости от состояния
                Image(image)
                    .resizable(capInsets: EdgeInsets(
                        top: cornerInset,
                        leading: cornerInset,
                        bottom: cornerInset,
                        trailing: cornerInset
                    ), resizingMode: .stretch)
                    .frame(width: width, height: height)
                    .opacity(isEnabled ? 1.0 : 0.5) // Полупрозрачность для неактивного состояния
                
                Text(text)
                    .font(Font.custom("DMSans-Bold", size: 16.5))
                    .kerning(3.2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isEnabled ? 
                        Color(red: 0.79, green: 1, blue: 1) : 
                        Color(red: 0.79, green: 1, blue: 1).opacity(0.6)) // Приглушенный цвет для неактивного состояния
                    .textCase(.uppercase)
                    .adaptiveOffset(x: offsetX, y: offsetY)
                    .blur(radius: 0.5)
            }
        }
        .frame(width: width, height: height)
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled) // Системное отключение кнопки
        .animation(.easeInOut(duration: 0.2), value: isEnabled) // Плавный переход между состояниями
    }
}
#Preview {
    VStack(spacing: 20) {
        // Активная кнопка
        CustomButtonAdaptiveRoom(
            text: "continue", 
            width: 390, 
            height: 266, 
            image: "BGRename", 
            offsetX: 0, 
            offsetY: 17, 
            isEnabled: true
        ) {
            print("Active button tapped")
        }
        
        // Неактивная кнопка
        CustomButtonAdaptiveRoom(
            text: "continue", 
            width: 390, 
            height: 266, 
            image: "BGRename", 
            offsetX: 0, 
            offsetY: 17, 
            isEnabled: false
        ) {
            print("Disabled button tapped - this shouldn't appear")
        }
    }
}


