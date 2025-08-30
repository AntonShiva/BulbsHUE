import SwiftUI

enum StyleType: String, CaseIterable {
    case classic = "classic"
    case pulse = "pulse"
    
    var displayName: String {
        switch self {
        case .classic:
            return String(localized: "CLASSIC")
        case .pulse:
            return String(localized: "PULSE")
        }
    }
}



// Версия с биндингом для использования в родительских View
struct StyleSettingView_Bindable: View {
    @Binding var selectedStyle: StyleType
    @State private var isExpanded: Bool = false
    
    var body: some View {
        // Основная ячейка (фиксированный размер)
        ZStack {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 332, height: 64)
                .background(Color(red: 0.99, green: 0.98, blue: 0.84))
                .cornerRadius(12)
                .opacity(isExpanded ? 0 : 0.1)
            
            HStack {
                // Icon placeholder
                ZStack {
                    // Здесь можно добавить иконку
                }
                .frame(width: 32, height: 32)
                
                Spacer()
                
                // Title
                Text(String(localized: "STYLE"))
                    .font(Font.custom("DM Sans", size: 14))
                    .tracking(2.80)
                    .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                
                Spacer()
                
                // Current value
                Text(selectedStyle.displayName)
                    .font(Font.custom("DM Sans", size: 14).weight(.black))
                    .tracking(2.80)
                    .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                    .opacity(isExpanded ? 0 : 1)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: 332, height: 64)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
        .overlay(alignment: .bottom) {
            // Расширенные опции появляются как overlay снизу
            if isExpanded {
                ZStack {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 332, height: 64)
                        .background(Color(red: 0.99, green: 0.98, blue: 0.84))
                        .cornerRadius(12)
                        .opacity(0.1)
                    
                    HStack(spacing: 0) {
                        // Classic option
                        Button(action: {
                            selectedStyle = .classic
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded = false
                            }
                        }) {
                            Text(StyleType.classic.displayName)
                                .font(Font.custom("DM Sans", size: 14).weight(selectedStyle == .classic ? .black : .medium))
                                .tracking(2.80)
                                .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Pulse option
                        Button(action: {
                            selectedStyle = .pulse
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded = false
                            }
                        }) {
                            Text(StyleType.pulse.displayName)
                                .font(Font.custom("DM Sans", size: 14).weight(selectedStyle == .pulse ? .black : .medium))
                                .tracking(2.80)
                                .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                }
                .offset(y: 64) // Сдвигаем на высоту основной ячейки
                .scaleEffect(x: 1, y: isExpanded ? 1 : 0, anchor: .top)
                .opacity(isExpanded ? 1 : 0)
                .zIndex(1) // Поверх других элементов
            }
        }
        .zIndex(isExpanded ? 10 : 1) // Весь компонент поверх других при расширении
    }
}

// Preview
#Preview {
    ZStack {
        BG()
        
        // Пример с биндингом
        StyleSettingView_Bindable(selectedStyle: .constant(.classic))
        
        
    }
}
