//
//  MenuView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/13/25.
//

import SwiftUI
import Combine

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
    
    /// Статическая переменная для хранения подписок Combine
    private static var cancellables = Set<AnyCancellable>()
    
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
                    
                    // Получаем текущую выбранную лампу из NavigationManager
                    guard let currentLight = NavigationManager.shared.selectedLightForMenu else {
                        print("❌ Ошибка: Нет выбранной лампы для обновления типа")
                        return
                    }
                    
                    // Используем UpdateLightTypeUseCase для сохранения изменений
                    let updateUseCase = DIContainer.shared.updateLightTypeUseCase
                    let input = UpdateLightTypeUseCase.Input(
                        lightId: currentLight.id,
                        userSubtypeName: typeName,
                        userSubtypeIcon: iconName
                    )
                    
                    // Выполняем обновление через Combine
                    updateUseCase.execute(input)
                        .receive(on: DispatchQueue.main)
                        .sink(
                            receiveCompletion: { completion in
                                switch completion {
                                case .finished:
                                    print("✅ Тип лампы успешно обновлен: \(typeName)")
                                    
                                    // Обновляем selectedLightForMenu с новыми данными
                                    var updatedLight = currentLight
                                    updatedLight.metadata.userSubtypeName = typeName
                                    updatedLight.metadata.userSubtypeIcon = iconName
                                    NavigationManager.shared.selectedLightForMenu = updatedLight
                                    
                                case .failure(let error):
                                    print("❌ Ошибка при обновлении типа лампы: \(error.localizedDescription)")
                                }
                            },
                            receiveValue: { _ in
                                // Операция завершена успешно
                            }
                        )
                        .store(in: &Self.cancellables)
                },
                onRename: { newName in
                    print("✏️ Rename bulb to: \(newName)")
                    // Переименование реализовано в UniversalMenuView через Use Cases
                },
                onReorganize: {
                    print("📋 Reorganize bulb pressed")
                    // TODO: Реализовать реорганизацию лампы
                },
                onDelete: {
                    print("🗑️ Delete bulb pressed")
                    
                    // Получаем текущую выбранную лампу из NavigationManager
                    guard let currentLight = NavigationManager.shared.selectedLightForMenu else {
                        print("❌ Ошибка: Нет выбранной лампы для удаления")
                        return
                    }
                    
                    // Используем DeleteLightUseCase для удаления лампы
                    let deleteLightUseCase = DIContainer.shared.deleteLightUseCase
                    let input = DeleteLightUseCase.Input(
                        lightId: currentLight.id,
                        roomId: nil // nil означает полное удаление из Environment
                    )
                    
                    // Выполняем удаление через Combine
                    deleteLightUseCase.execute(input)
                        .receive(on: DispatchQueue.main)
                        .sink(
                            receiveCompletion: { completion in
                                switch completion {
                                case .finished:
                                    print("✅ Лампа '\(currentLight.metadata.name)' успешно удалена из Environment")
                                    
                                    // Очищаем selectedLightForMenu
                                    NavigationManager.shared.selectedLightForMenu = nil
                                    
                                    // Закрываем меню
                                    NavigationManager.shared.hideMenuView()
                                    
                                case .failure(let error):
                                    print("❌ Ошибка при удалении лампы: \(error.localizedDescription)")
                                }
                            },
                            receiveValue: { _ in
                                // Операция завершена успешно
                            }
                        )
                        .store(in: &Self.cancellables)
                }
            )
        )
    }
}
#Preview {
    MenuView(bulbName: "Ламочка ул", bulbIcon: "f2", bulbType: "Лщджия")
        .environment(NavigationManager.shared)
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=120-879&t=aTBbxHC3igKeQH3e-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
       
}
#Preview {
    MenuView(bulbName: "bulb name", bulbIcon: "t1", bulbType: "Лщджия")
        .environment(NavigationManager.shared)
}



