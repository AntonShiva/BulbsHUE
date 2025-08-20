import SwiftUI

// MARK: - Универсальная ячейка подтипа
struct SubtypeCell<SubtypeType: SubtypeCellData>: View {
    let subtype: SubtypeType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Иконка подтипа - автоматически подставляется правильная иконка из Assets
            Image(subtype.iconName)
                .resizable()
                .scaledToFit()
                .adaptiveFrame(width: 24, height: 24)
                .adaptiveFrame(width: 66) // Выровнено с основной ячейкой
                .adaptiveOffset(x: 17)
            
            // Название подтипа - берется из модели данных
            Text(subtype.name)
                .font(Font.custom("DMSans-Light", size: 12))
                .kerning(2.4)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveOffset(x: -8)
            
            // Индикатор выбора - показывает реальное состояние выбора
            SelectionIndicator(isSelected: isSelected)
                .adaptiveFrame(width: 50) // Выровнено с шевроном
        }
        .adaptivePadding(.trailing, 10) // Такой же отступ как в основной ячейке
        .adaptiveFrame(width: 332, height: 28) // Такая же ширина как основная ячейка
        .contentShape(Rectangle()) // Вся область ячейки кликабельна
        .onTapGesture {
            onSelect() // Вызывает callback для переключения состояния
        }
    }
}

// MARK: - Удобные типализованные инициализаторы
extension SubtypeCell where SubtypeType == LampSubtype {
    /// Создает ячейку для подтипа лампы
    init(lampSubtype: LampSubtype, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.subtype = lampSubtype
        self.isSelected = isSelected
        self.onSelect = onSelect
    }
}

extension SubtypeCell where SubtypeType == RoomSubtype {
    /// Создает ячейку для подтипа комнаты
    init(roomSubtype: RoomSubtype, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.subtype = roomSubtype
        self.isSelected = isSelected
        self.onSelect = onSelect
    }
}

// MARK: - Type aliases для удобства использования
typealias LampSubtypeCell = SubtypeCell<LampSubtype>
typealias RoomSubtypeCell = SubtypeCell<RoomSubtype>

// MARK: - Preview
#Preview {
    ZStack {
        BG()
        VStack(spacing: 16) {
            // Пример для лампы
            SubtypeCell(
                lampSubtype: LampSubtype(name: "TRADITIONAL LAMP", iconName: "t1"),
                isSelected: true
            ) {
                print("Lamp subtype selected")
            }
            
            // Пример для комнаты
            SubtypeCell(
                roomSubtype: RoomSubtype(name: "LIVING ROOM", iconName: "tr1", roomType: .livingRoom),
                isSelected: false
            ) {
                print("Room subtype selected")
            }
        }
    }
}
