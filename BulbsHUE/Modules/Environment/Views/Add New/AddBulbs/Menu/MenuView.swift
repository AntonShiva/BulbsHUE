//
//  MenuView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/13/25.
//

import SwiftUI

/// Меню настроек для лампы (обновленная версия, использующая универсальные компоненты)
/// Теперь является оберткой над UniversalMenuView для обратной совместимости
struct MenuView: View {
    let bulbName: String
    /// Тип лампы (пользовательский подтип)
    let bulbType: String
   /// Иконка лампы
    let bulbIcon: String
    /// Базовый цвет для фона компонента
    let baseColor: Color
    
    /// Инициализатор для создания меню лампы
    /// - Parameters:
    ///   - bulbName: Название лампы
    ///   - bulbIcon: Иконка лампы
    ///   - bulbType: Тип лампы
    ///   - baseColor: Базовый цвет для интерфейса
    init(bulbName: String,
         bulbIcon: String,
         bulbType: String,
         baseColor: Color = .purple) {
        self.bulbName = bulbName
        self.bulbIcon = bulbIcon
        self.bulbType = bulbType
        self.baseColor = baseColor
    }
    
    var body: some View {
        // Используем универсальное меню с конфигурацией для лампы
        UniversalMenuView(
            itemData: .bulb(
                title: bulbName,
                subtitle: bulbType,
                icon: bulbIcon,
                baseColor: baseColor,
                bottomText: "no room"
            ),
            menuConfig: .forBulb(
                icon: bulbIcon,
                onChangeType: {
                    print("🔄 Change bulb type pressed")
                    // TODO: Реализовать смену типа лампы
                },
                onTypeChanged: { typeName, iconName in
                    print("✅ Bulb type changed to: \(typeName), icon: \(iconName)")
                    // TODO: Сохранить новый тип лампы в модель данных
                    // Здесь нужно обновить selectedLightForMenu с новым типом
                },
                onRename: { newName in
                    print("✏️ Rename bulb to: \(newName)")
                    // TODO: Реализовать переименование лампы
                },
                onReorganize: {
                    print("📋 Reorganize bulb pressed")
                    // TODO: Реализовать реорганизацию лампы
                },
                onDelete: {
                    print("🗑️ Delete bulb pressed")
                    // TODO: Реализовать удаление лампы
                }
            )
        )
    }
}
#Preview {
    MenuView(bulbName: "Ламочка ул", bulbIcon: "f2", bulbType: "Лщджия")
        .environmentObject(NavigationManager.shared)
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=120-879&t=aTBbxHC3igKeQH3e-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
       
}
#Preview {
    MenuView(bulbName: "bulb name", bulbIcon: "t1", bulbType: "Лщджия")
        .environmentObject(NavigationManager.shared)
}



