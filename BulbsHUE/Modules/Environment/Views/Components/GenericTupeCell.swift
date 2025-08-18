//
//  GenericTupeCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 18.08.2025.
//

import SwiftUI

// MARK: - Обобщенная расширяемая ячейка типа
struct GenericTupeCell<DataType: TypeCellData, ManagerType: TypeManager, SubtypeCellView: View>: View 
where DataType.SubtypeType == ManagerType.SubtypeType {
    let typeData: DataType
    @ObservedObject var typeManager: ManagerType
    let subtypeCellBuilder: (DataType.SubtypeType, Bool, @escaping () -> Void) -> SubtypeCellView
    var cellHeight: CGFloat = 64 // Настраиваемая высота
    
    @State private var isExpanded: Bool = false
    
    // Вычисляет общую высоту ячейки в зависимости от развернутого состояния
    private var totalHeight: CGFloat {
        if isExpanded && !typeData.subtypes.isEmpty {
            let subtypeHeight: CGFloat = 40 // Высота каждого подтипа
            let spacing: CGFloat = 8 // Отступ между подтипами
            let padding: CGFloat = 16 // Отступы сверху и снизу
            return cellHeight + (CGFloat(typeData.subtypes.count) * subtypeHeight) + (CGFloat(typeData.subtypes.count - 1) * spacing) + padding
        } else {
            return cellHeight
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Расширяемый фон
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 332, height: totalHeight)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(15)
                .opacity(0.1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            
            VStack(spacing: 0) {
                // Основная ячейка (неизменная часть)
                ZStack {
                    HStack {
                        HStack(spacing: 0) {
                            // Иконка типа - автоматически берется из typeData
                            Image(typeData.iconName)
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: typeData.iconWidth, height: typeData.iconHeight)
                                .adaptiveFrame(width: 66) // Фиксированная область для иконки
                            
                            // Название типа - берется из typeData
                            Text(typeData.name)
                                .font(Font.custom("DMSans-Regular", size: 14))
                                .kerning(3)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Кнопка с поворотом - поворачивается только если есть подтипы
                            ChevronButton{
                                if !typeData.subtypes.isEmpty {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isExpanded.toggle()
                                    }
                                }
                            }
                            .rotationEffect(.degrees(isExpanded && !typeData.subtypes.isEmpty ? 90 : 0))
                            .adaptiveFrame(width: 50)
                        }
                        .adaptivePadding(.trailing, 10)
                    }
                    .adaptiveFrame(width: 332, height: cellHeight)
                }
                
                // Развернутый список подтипов с реальными данными
                if isExpanded && !typeData.subtypes.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(typeData.subtypes.enumerated()), id: \.element.id) { index, subtype in
                            subtypeCellBuilder(
                                subtype,
                                typeManager.isSubtypeSelected(subtype),
                                {
                                    // Выбираем только один подтип (отменяя предыдущий)
                                    typeManager.selectSubtype(subtype)
                                }
                            )
                        }
                    }
                    .adaptivePadding(.top, 8)
                    .adaptivePadding(.bottom, 8)
                    .opacity(isExpanded ? 1 : 0)
                }
            }
        }
    }
}

// MARK: - Типизированные версии для удобства использования

// Ячейка для типов ламп
struct LampTupeCell: View {
    let bulbType: BulbType
    @ObservedObject var typeManager: BulbTypeManager
    var cellHeight: CGFloat = 64
    
    var body: some View {
        GenericTupeCell(
            typeData: bulbType,
            typeManager: typeManager,
            subtypeCellBuilder: { subtype, isSelected, onSelect in
                LampSubtypeCell(
                    subtype: subtype,
                    isSelected: isSelected,
                    onSelect: onSelect
                )
            },
            cellHeight: cellHeight
        )
    }
}

// Ячейка для категорий комнат
struct RoomTupeCell: View {
    let roomCategory: RoomCategory
    @ObservedObject var categoryManager: RoomCategoryManager
    var cellHeight: CGFloat = 64
    
    var body: some View {
        GenericTupeCell(
            typeData: roomCategory,
            typeManager: categoryManager,
            subtypeCellBuilder: { subtype, isSelected, onSelect in
                RoomSubtypeCell(
                    subtype: subtype,
                    isSelected: isSelected,
                    onSelect: onSelect
                )
            },
            cellHeight: cellHeight
        )
    }
}

// MARK: - Обратная совместимость
// Переименовываем старую TupeCell в LampTupeCell для обратной совместимости
typealias TupeCell = LampTupeCell
