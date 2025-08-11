//
//  ItemControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import SwiftUI

/// Компонент для управления отдельной лампой
/// Использует изолированную ViewModel для каждой лампы
struct ItemControl: View {
    // MARK: - Environment Objects
    /// Основной ViewModel приложения для доступа к сервисам
    @EnvironmentObject var appViewModel: AppViewModel
    
    // MARK: - Properties
    
    /// Лампа для отображения и управления
    let light: Light
    
    /// Изолированная ViewModel для этой конкретной лампы
    @StateObject private var itemControlViewModel: ItemControlViewModel
    
    // MARK: - Initialization
    
    /// Инициализация с созданием изолированной ViewModel для лампы
    /// - Parameter light: Лампа для управления
    init(light: Light) {
        self.light = light
        
        // Создаем изолированную ViewModel для этой лампы
        // Инициализируется с пустым сервисом, будет настроена в onAppear
        self._itemControlViewModel = StateObject(wrappedValue: ItemControlViewModel.createIsolated())
    }

    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                // Основной контрол с динамическими данными из ViewModel
                ControlView(
                    isOn: $itemControlViewModel.isOn,
                    baseColor: itemControlViewModel.defaultWarmColor,
                    bulbName: light.metadata.name,
                    bulbType: itemControlViewModel.getBulbType(),
                    roomName: itemControlViewModel.getRoomName(),
                    bulbIcon: itemControlViewModel.getBulbIcon(),
                    roomIcon: itemControlViewModel.getRoomIcon(),
                    onToggle: { newState in
                        // Обновляем состояние через ViewModel
                        itemControlViewModel.setPower(newState)
                    }
                )
                
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
                .adaptiveOffset(x: 40, y: -8)
            }
            
            // Слайдер яркости справа
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
            .padding(.leading, 10)
        }
        .onAppear {
            // Конфигурируем изолированную ViewModel с сервисом из appViewModel
            itemControlViewModel.configure(
                with: LightControlService(appViewModel: appViewModel),
                light: light
            )
        }
        .onChange(of: light) { newLight in
            // Обновляем лампу если она изменилась извне
            itemControlViewModel.setCurrentLight(newLight)
        }
    }

}

#Preview {
    let appViewModel = AppViewModel()
    
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
}
