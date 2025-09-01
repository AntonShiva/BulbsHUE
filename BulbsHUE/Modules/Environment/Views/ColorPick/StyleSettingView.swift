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
struct StyleSettingView: View {
    @Binding var selectedStyle: StyleType
    @Binding var isExpanded: Bool
    
    var body: some View {
        // Основная ячейка (фиксированный размер)
        ZStack {
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 332, height: 64)
                .background(Color(red: 0.99, green: 0.98, blue: 0.84))
                .cornerRadius(12)
                .opacity(isExpanded ? 0 : 0.1)
            
            ZStack {
                // Icon placeholder
              Image("Stule")
                    .resizable()
                    .scaledToFit()
                .adaptiveFrame(width: 22, height: 22)
                .adaptiveOffset(x: -134)
                .opacity(isExpanded ? 0 : 1)
                
                // Title
                Text(String(localized: "STYLE"))
                    .font(Font.custom("DMSans-Regular", size: 14.3))
                    .tracking(2.80)
                    .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                    .adaptiveOffset(x: isExpanded ? 0 : -67 )
               
                
                // Current value
                Text(selectedStyle.displayName)
                    .font(Font.custom("DMSans-Black", size: 14))
                    .tracking(2.80)
                    .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                    .opacity(isExpanded ? 0 : 1)
                    .adaptiveOffset(x: 96)
            }
           
        }
        .adaptiveFrame(width: 332, height: 64)
        
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
                        .adaptiveFrame(width: 332, height: 64)
                        .background(Color(red: 0.99, green: 0.98, blue: 0.84))
                        .cornerRadius(12)
                        .opacity(0.1)
                    
                    HStack(spacing: 0) {
                        // Classic option
                        Button(action: {
                            selectedStyle = .classic
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                isExpanded = false
//                            }
                        }) {
                            ZStack {
                               UnevenRoundedRectangle(
                                    topLeadingRadius: 12,
                                    bottomLeadingRadius: 12,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 0
                                )
                                .fill(Color(red: 0.99, green: 0.98, blue: 0.84))
                              .adaptiveFrame(width: 166, height: 64)
                              .opacity(selectedStyle == .classic ? 0.1 : 0)
                            
                               
                                
                                Text(StyleType.classic.displayName)
                                    .font(Font.custom("DM Sans", size: 14).weight(selectedStyle == .classic ? .black : .medium))
                                    .tracking(2.80)
                                    .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                                    
                            }
                        }
                        
                        
                        // Pulse option
                        Button(action: {
                            selectedStyle = .pulse
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                isExpanded = false
//                            }
                        }) {
                            ZStack {
                                UnevenRoundedRectangle(
                                     topLeadingRadius: 0,
                                     bottomLeadingRadius: 0,
                                     bottomTrailingRadius: 12,
                                     topTrailingRadius: 12
                                 )
                                 .fill(Color(red: 0.99, green: 0.98, blue: 0.84))
                               .adaptiveFrame(width: 166, height: 64)
                               .opacity(selectedStyle == .pulse ? 0.1 : 0)
                                
                                Text(StyleType.pulse.displayName)
                                    .font(Font.custom("DM Sans", size: 14).weight(selectedStyle == .pulse ? .black : .medium))
                                    .tracking(2.80)
                                    .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                            }
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
        StyleSettingView(
            selectedStyle: .constant(.classic),
            isExpanded: .constant(false)
        )
        
        
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2242-9&t=ecwoqnlqZqm7Kwrp-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
