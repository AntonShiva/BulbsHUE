//
//  TupeCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

// MARK: - Расширяемая ячейка типа лампы
struct TupeCell: View {
    let bulbType: BulbType
    @ObservedObject var typeManager: BulbTypeManager
    var cellHeight: CGFloat = 64 // Настраиваемая высота
    
    @State private var isExpanded: Bool = false
    
    // Вычисляет общую высоту ячейки в зависимости от развернутого состояния
    private var totalHeight: CGFloat {
        if isExpanded && !bulbType.subtypes.isEmpty {
            let subtypeHeight: CGFloat = 40 // Высота каждого подтипа
            let spacing: CGFloat = 8 // Отступ между подтипами
            let padding: CGFloat = 16 // Отступы сверху и снизу
            return cellHeight + (CGFloat(bulbType.subtypes.count) * subtypeHeight) + (CGFloat(bulbType.subtypes.count - 1) * spacing) + padding
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
                            // Иконка типа лампы - автоматически берется из bulbType
                            Image(bulbType.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: bulbType.iconWidth, height: bulbType.iconHeight)
                                .frame(width: 66) // Фиксированная область для иконки
                            
                            // Название типа лампы - берется из bulbType
                            Text(bulbType.name)
                                .font(Font.custom("DMSans-Regular", size: 14))
                                .kerning(3)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Кнопка с поворотом - поворачивается только если есть подтипы
                            ChevronButton{
                                if !bulbType.subtypes.isEmpty {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isExpanded.toggle()
                                    }
                                }
                            }
                            .rotationEffect(.degrees(isExpanded && !bulbType.subtypes.isEmpty ? 90 : 0))
                            .adaptiveFrame(width: 50)
                        }
                        .padding(.trailing, 10)
                    }
                    .frame(width: 332, height: cellHeight)
                }
                
                // Развернутый список подтипов с реальными данными
                if isExpanded && !bulbType.subtypes.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(bulbType.subtypes, id: \.id) { subtype in
                            LampSubtypeCell(
                                subtype: subtype,
                                isSelected: typeManager.isSubtypeSelected(subtype),
                                onSelect: {
                                    // Выбираем только один подтип (отменяя предыдущий)
                                    typeManager.selectSubtype(subtype)
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


// MARK: - Простая ячейка без расширения (для SearchResultsSheet)
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
                    ChevronButton {
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

// MARK: - Preview для TupeCell с реальными данными
#Preview {
    ZStack {
        BG()
        VStack(spacing: 16) {
            // Создаем тестовый typeManager
            let typeManager = BulbTypeManager()
            let tableType = typeManager.bulbTypes.first { $0.name == "TABLE" }!
            
            TupeCell(
                bulbType: tableType,
                typeManager: typeManager
            )
        }
    }
    .environmentObject(NavigationManager.shared)
    .environmentObject(AppViewModel())
}
