import SwiftUI

// MARK: - Ячейка выбора лампы
struct LightSelectionCell: View {
    let light: LightEntity
    let isSelected: Bool
    let onSelect: () -> Void
    
    // Computed property для определения доступности лампы
    private var isSelectable: Bool {
        return light.roomId == nil && light.isReachable
    }
    
    var body: some View {
        ZStack {
            // Фон ячейки
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 332, height: 64)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(15)
                .opacity(isSelectable ? 0.1 : 0.05) // Приглушенный фон для недоступных ламп
            
            // Контент ячейки
            HStack {
                HStack(spacing: 0) {
                    // Иконка лампы - показываем иконку типа лампы
                    Image(light.type.rawValue.lowercased())
                        .resizable()
                        .scaledToFit()
                        .adaptiveFrame(width: 24, height: 24)
                        .adaptiveFrame(width: 66) // Фиксированная ширина для области иконки
                        .opacity(isSelectable ? 1.0 : 0.5) // Приглушенная иконка для недоступных ламп
                    
                    // Информация о лампе
                    VStack(alignment: .leading, spacing: 2) {
                        // Название лампы
                        Text(light.name)
                            .font(Font.custom("DMSans-Regular", size: 14))
                            .kerning(3)
                            .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                            .opacity(isSelectable ? 1.0 : 0.5) // Приглушенный текст для недоступных ламп
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
               
                    }
                      
                    // CheckView вместо шеврона (только для доступных ламп)
                    if isSelectable {
                        CheckView(isActive: isSelected)
                            .adaptiveFrame(width: 50) // Фиксированная ширина для CheckView
                    } else {
                        // Пустое место вместо CheckView для недоступных ламп
                        Rectangle()
                            .foregroundColor(.clear)
                            .adaptiveFrame(width: 50, height: 48)
                    }
                }
                .adaptivePadding(.trailing, 10)
            }
            .adaptiveFrame(width: 332, height: 64)
        }
        .contentShape(Rectangle()) // Вся область ячейки кликабельна
        .onTapGesture {
            if isSelectable {
                onSelect()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        BG()
        VStack(spacing: 16) {
            LightSelectionCell(
                light: LightEntity(
                    id: "1",
                    name: "Living Room Light",
                    type: .ceiling,
                    subtype: .ceilingRound,
                    isOn: true,
                    brightness: 75.0,
                    color: nil,
                    colorTemperature: 3000,
                    isReachable: true,
                    roomId: nil,
                    userSubtype: nil,
                    userIcon: nil
                ),
                isSelected: true
            ) {
                print("Light selected")
            }
            
            LightSelectionCell(
                light: LightEntity(
                    id: "2",
                    name: "Table Lamp",
                    type: .table,
                    subtype: .traditionalLamp,
                    isOn: false,
                    brightness: 0.0,
                    color: nil,
                    colorTemperature: 2700,
                    isReachable: true,
                    roomId: "room-123",
                    userSubtype: nil,
                    userIcon: nil
                ),
                isSelected: false
            ) {
                print("Light selected")
            }
        }
    }
}
