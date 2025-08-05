//
//  TupeCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI
// MARK: - Модель данных для подтипа лампы
struct LampSubtype {
    let id = UUID()
    let name: String
    let iconName: String
    let isSelected: Bool
}

// MARK: - Расширяемая ячейка
struct TupeCell: View {
    var text: String
    var image: String
    var width: CGFloat
    var height: CGFloat
    var cellHeight: CGFloat = 64 // Настраиваемая высота
    var subtypes: [LampSubtype] = [] // Подтипы для развернутого состояния
    var onTap: () -> Void = {}
    var onSubtypeSelect: (LampSubtype) -> Void = { _ in }
    
    @State private var isExpanded: Bool = false
    
    private var totalHeight: CGFloat {
        if isExpanded {
            let subtypeHeight: CGFloat = 40 // Высота каждого подтипа
            let spacing: CGFloat = 8 // Отступ между подтипами
            let padding: CGFloat = 16 // Отступы сверху и снизу
            return cellHeight + (CGFloat(subtypes.count) * subtypeHeight) + (CGFloat(subtypes.count - 1) * spacing) + padding
        } else {
            return cellHeight
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Расширяемый фон
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 332, height: totalHeight)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(15)
                .opacity(0.1)
//                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                .transition(.opacity.combined(with: .move(edge: .top)))
            
            VStack(spacing: 0) {
                // Основная ячейка (неизменная часть)
                ZStack {
                    HStack {
                        HStack(spacing: 0) {
                            // Иконка - фиксированная позиция слева
                            Image(image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: width, height: height)
                                .frame(width: 66)
                            
                            // Текст - начинается в фиксированной позиции
                            Text(text)
                                .font(Font.custom("DMSans-Regular", size: 14))
                                .kerning(3)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                         
                            // Кнопка с поворотом
                            SelectCategoryButton{
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isExpanded.toggle()
                                }
                                onTap()
                            }
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .adaptiveFrame(width: 50)
                        }
                        .padding(.trailing, 10)
                    }
                    .frame(width: 332, height: cellHeight)
                }
                
                // Развернутый список подтипов
                if isExpanded && !subtypes.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(subtypes, id: \.id) { subtype in
                            LampSubtypeCell(
                                subtype: subtype,
                                onSelect: {
                                    onSubtypeSelect(subtype)
                                }
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .opacity(isExpanded ? 1 : 0)
                }
            }
        }
    }
}


struct BulbCell: View {
    var text: String
    var image: String
    var width: CGFloat
    var height: CGFloat
    var onTap: () -> Void = {}
    
    var body: some View {
        ZStack {
            // Фон ячейки
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 332, height: 64)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(15)
                .opacity(0.1)
            
            // Контент ячейки
            HStack {
                HStack(spacing: 0) {
                    // Иконка - фиксированная позиция слева
                    Image(image)
                        .resizable()
                        .scaledToFit()
                        .adaptiveFrame(width: width, height: height)
                        .adaptiveFrame(width: 66) // Фиксированная ширина для области иконки
                    
                    // Текст - начинается в фиксированной позиции
                    Text(text)
                        .font(Font.custom("DMSans-Regular", size: 14))
                        .kerning(3)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, alignment: .leading) // Выравнивание по левому краю
                      
                    // Кнопка - фиксированная позиция справа
                    SelectCategoryButton {
                                            onTap()
                    }
                    .adaptiveFrame(width: 50) // Фиксированная ширина для кнопки
                }
                .padding(.trailing, 10)
            }
            .adaptiveFrame(width: 332, height: 64)
        }
    }
}
struct ExpandableCellTestView_Previews1: PreviewProvider {
    static var previews: some View {
        ExpandableCellTestView()
    }
}


#Preview {
    ZStack {
       BG()
       BulbCell(text: "Bulb name", image: "lightBulb", width: 32, height: 32)
            .adaptiveOffset(y: -70)
    }
    .environmentObject(NavigationManager.shared)
    .environmentObject(AppViewModel())
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

#Preview {
    SearchResultsSheet()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
