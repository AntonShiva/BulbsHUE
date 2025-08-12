//
//  ControlView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/8/25.
//

import SwiftUI

/// Компонент для отображения основной информации о лампе
/// Принимает динамические данные через параметры
struct ControlView: View {
    // MARK: - Properties
    
    /// Состояние включения/выключения лампы
    @Binding var isOn: Bool
    
    /// Базовый цвет для фона компонента
    let baseColor: Color
    
    /// Название лампы
    let bulbName: String
    
    /// Тип лампы
    let bulbType: String
    
    /// Название комнаты
    let roomName: String
    
    /// Иконка лампы
    let bulbIcon: String
    
    /// Иконка комнаты/типа
    let roomIcon: String
    
    /// Callback для обработки изменения состояния питания
    let onToggle: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    init(
        isOn: Binding<Bool>,
        baseColor: Color = .purple,
        bulbName: String = "Smart Bulb",
        bulbType: String = "Smart Light",
        roomName: String = "Living Room",
        bulbIcon: String = "f2",
        roomIcon: String = "tr1",
        onToggle: ((Bool) -> Void)? = nil
    ) {
        self._isOn = isOn
        self.baseColor = baseColor
        self.bulbName = bulbName
        self.bulbType = bulbType
        self.roomName = roomName
        self.bulbIcon = bulbIcon
        self.roomIcon = roomIcon
        self.onToggle = onToggle
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Фоновый элемент с цветным градиентом
            BGItem(baseColor: baseColor)
                .adaptiveFrame(width: 278, height: 140)
            
            // Иконка лампы (слева вверху)
            Image(bulbIcon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(baseColor.preferredForeground)
                .adaptiveFrame(width: 32, height: 32)
                .adaptiveOffset(x: -100, y: -42)
            
            // Название лампы (основной текст)
            Text(bulbName)
                .font(Font.custom("DMSans-Regular", size: 20))
                .kerning(4)
                .foregroundColor(baseColor.preferredForeground)
                .textCase(.uppercase)
                .adaptiveOffset(x: -45, y: -3)
            
            // Тип лампы (подзаголовок)
            Text(bulbType)
                .font(Font.custom("DMSans-Light", size: 14))
                .kerning(2.8)
                .foregroundColor(baseColor.preferredForeground.opacity(0.9))
                .textCase(.uppercase)
                .adaptiveOffset(x: -63, y: 19)
            
            // Разделительная линия
            Rectangle()
                .fill(Color(red: 0.79, green: 1, blue: 1))
                .adaptiveFrame(width: 153, height: 2)
                .opacity(0.2)
                .adaptiveOffset(x: -42, y: 33)
            
            // Иконка комнаты
            Image(roomIcon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(baseColor.preferredForeground)
                .adaptiveFrame(width: 16, height: 16)
                .adaptiveOffset(x: -108, y: 46)
            
            // Название комнаты
            Text(roomName)
                .font(Font.custom("DMSans-Light", size: 12))
                .kerning(2.4)
                .foregroundColor(baseColor.preferredForeground.opacity(0.9))
                .textCase(.uppercase)
                .adaptiveOffset(x: -42, y: 46)
            
            // Переключатель включения/выключения
            CustomToggle(isOn: $isOn)
                .adaptiveOffset(x: 95, y: 42)
                .onChange(of: isOn) { newValue in
                    // Вызываем callback при изменении состояния
                    onToggle?(newValue)
                }
            
            // Кнопка дополнительных настроек (справа вверху)
            ZStack {
                BGCircle()
                    .adaptiveFrame(width: 36, height: 36)
                
                Image(systemName: "ellipsis")
                    .font(.system(size: 22))
                    .foregroundColor(baseColor.preferredForeground)
                    .rotationEffect(Angle(degrees: 90))
            }
            .adaptiveOffset(x: 111, y: -43)
        }
    }
}

#Preview {
    ControlView(isOn: .constant(true))
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=Oz8YTfvXva0QJfVZ-4")!)
       
}
