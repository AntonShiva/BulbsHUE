//
//  TupeCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

// MARK: - Универсальная расширяемая ячейка типа
struct TupeCell<DataType: TypeCellData, ManagerType: TypeManager, SubtypeCellView: View>: View 
where DataType.SubtypeType == ManagerType.SubtypeType {
    let typeData: DataType
    @Bindable var typeManager: ManagerType
    let subtypeCellBuilder: (DataType.SubtypeType, Bool, @escaping () -> Void) -> SubtypeCellView
    var cellHeight: CGFloat = 64 // Настраиваемая высота
    var iconWidth: CGFloat? = nil // Переопределение ширины иконки
    var iconHeight: CGFloat? = nil // Переопределение высоты иконки
    
    @State private var isExpanded: Bool = false
    
    // Вычисленные размеры иконки - используем переопределенные или из typeData
    private var actualIconWidth: CGFloat {
        iconWidth ?? typeData.iconWidth
    }
    
    private var actualIconHeight: CGFloat {
        iconHeight ?? typeData.iconHeight
    }
    
    // Вычисляет общую высоту ячейки в зависимости от развернутого состояния
    private var totalHeight: CGFloat {
        if isExpanded && !typeData.subtypes.isEmpty {
            let subtypeHeight: CGFloat = 30 // Точная высота каждого подтипа
            let spacing: CGFloat = 15
            let topPadding: CGFloat = 24 // Отступ сверху
            let bottomPadding: CGFloat = 4 // Минимальный отступ снизу
            return cellHeight + (CGFloat(typeData.subtypes.count) * subtypeHeight) + (CGFloat(typeData.subtypes.count - 1) * spacing) + topPadding + bottomPadding
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
                            // Иконка типа - используем настраиваемые или стандартные размеры
                            Image(typeData.iconName)
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: actualIconWidth, height: actualIconHeight)
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
                    VStack(spacing: 14) {
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
                    .adaptivePadding(.top, 16)
                    .adaptivePadding(.bottom, 4)
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
                .adaptivePadding(.trailing, 10)
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
            
            // Пример использования для ламп
            TupeCell(
                bulbType: tableType,
                typeManager: typeManager
            )
        }
    }
    .environment(NavigationManager.shared)
    .environment(AppViewModel())
}

// MARK: - Удобные расширения для создания типизированных ячеек
extension TupeCell where DataType == BulbType, ManagerType == BulbTypeManager, SubtypeCellView == SubtypeCell<LampSubtype> {
    /// Создает ячейку для типов ламп
    init(bulbType: BulbType, typeManager: BulbTypeManager, cellHeight: CGFloat = 64, iconWidth: CGFloat? = nil, iconHeight: CGFloat? = nil) {
        self.typeData = bulbType
        self.typeManager = typeManager
        self.cellHeight = cellHeight
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.subtypeCellBuilder = { subtype, isSelected, onSelect in
            SubtypeCell(
                lampSubtype: subtype,
                isSelected: isSelected,
                onSelect: onSelect
            )
        }
    }
}

extension TupeCell where DataType == RoomCategory, ManagerType == RoomCategoryManager, SubtypeCellView == SubtypeCell<RoomSubtype> {
    /// Создает ячейку для категорий комнат
    init(roomCategory: RoomCategory, categoryManager: RoomCategoryManager, cellHeight: CGFloat = 64, iconWidth: CGFloat? = nil, iconHeight: CGFloat? = nil) {
        self.typeData = roomCategory
        self.typeManager = categoryManager
        self.cellHeight = cellHeight
        self.iconWidth = iconWidth
        self.iconHeight = iconHeight
        self.subtypeCellBuilder = { subtype, isSelected, onSelect in
            SubtypeCell(
                roomSubtype: subtype,
                isSelected: isSelected,
                onSelect: onSelect
            )
        }
    }
}
