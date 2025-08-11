//
//  ItemControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import SwiftUI

/// Компонент для управления отдельной лампой
/// Использует современный подход MVVM с Environment objects
struct ItemControl: View {
    // MARK: - Environment Objects
    /// Основной ViewModel приложения
    @EnvironmentObject var appViewModel: AppViewModel
    
    /// ViewModel для управления состоянием лампы
    @EnvironmentObject var itemControlViewModel: ItemControlViewModel
    
    // MARK: - Properties
    
    /// Лампа для отображения и управления
    let light: Light

    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Основной контрол с динамическими данными из ViewModel
            ControlView(
                isOn: $itemControlViewModel.isOn,
                baseColor: itemControlViewModel.defaultWarmColor,
                bulbName: light.metadata.name,
                bulbType: itemControlViewModel.getBulbType(),
                roomName: itemControlViewModel.getRoomName(),
                bulbIcon: itemControlViewModel.getBulbIcon(),
                roomIcon: itemControlViewModel.getRoomIcon()
            )
            .adaptiveOffset(x: -36)
            
            // Статус питания и информация о лампе
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(itemControlViewModel.isOn ? Color.green.opacity(0.9) : Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text(itemControlViewModel.isOn ? "ON" : "OFF")
                        .font(Font.custom("DMSans-Medium", size: 11))
                        .foregroundStyle(itemControlViewModel.isOn ? Color.green.opacity(0.9) : Color.gray.opacity(0.8))
                        .textCase(.uppercase)
                }
                Text(itemControlViewModel.getRoomName())
                    .font(Font.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text(light.metadata.name)
                    .font(Font.custom("DMSans-Medium", size: 14))
                    .foregroundStyle(Color.white)
            }
            .adaptiveOffset(x: 4, y: -8)
            
            // Слайдер яркости с интеграцией ViewModel
            CustomSlider(
                percent: $itemControlViewModel.brightness,
                color: itemControlViewModel.defaultWarmColor,
                onChange: { value in
                    // Используем метод ViewModel для throttled обновлений
                    itemControlViewModel.setBrightnessThrottled(value)
                },
                onCommit: { value in
                    // Используем метод ViewModel для финального коммита
                    itemControlViewModel.commitBrightness(value)
                }
            )
            .adaptiveOffset(x: 143)
        }
        .onAppear {
            // Устанавливаем текущую лампу в ViewModel при появлении компонента
            itemControlViewModel.setCurrentLight(light)
        }
        .onChange(of: itemControlViewModel.isOn) { newValue in
            // Переключение питания через ViewModel (автоматически)
            // Логика уже встроена в ViewModel через @Published
        }
    }

}

#Preview {
    let appViewModel = AppViewModel()
    let itemControlViewModel = ItemControlViewModel.createMockViewModel()
    
    let mockLight = Light(
        id: "light_mock_01",
        type: "light",
        metadata: LightMetadata(name: "Smart Bulb", archetype: nil),
        on: OnState(on: true),
        dimming: Dimming(brightness: 75),
        color: nil,
        color_temperature: nil,
        effects: nil,
        effects_v2: nil,
        mode: nil,
        capabilities: nil,
        color_gamut_type: nil,
        color_gamut: nil,
        gradient: nil
    )
    
    ItemControl(light: mockLight)
        .environmentObject(appViewModel)
        .environmentObject(itemControlViewModel)
}
