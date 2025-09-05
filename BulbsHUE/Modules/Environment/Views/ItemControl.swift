//
//  ItemControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import SwiftUI
import Combine

/// Компонент для управления отдельной лампой
/// Использует изолированную ViewModel для каждой лампы
struct ItemControl: View {
    // MARK: - Environment Objects
    /// Основной ViewModel приложения для доступа к сервисам
    @Environment(AppViewModel.self) private var appViewModel
    /// Навигационный менеджер для управления переходами
    @Environment(NavigationManager.self) private var nav
    
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
                    baseColor: itemControlViewModel.dynamicColor, // ✅ Используем динамический цвет
                    bulbName: itemControlViewModel.currentLight?.metadata.name ?? light.metadata.name,
                    bulbType: itemControlViewModel.getBulbType(),
                    roomName: itemControlViewModel.getRoomName(),
                    bulbIcon: itemControlViewModel.getBulbIcon(),
                    roomIcon: itemControlViewModel.getRoomIcon(),
                    onToggle: { newState in
                        // Обновляем состояние через ViewModel
                        itemControlViewModel.setPower(newState)
                    },
                    onMenuTap: {
                        // Показываем MenuView для этой лампы (используем актуальную лампу из ViewModel)
                        if let currentLight = itemControlViewModel.currentLight {
                            nav.showMenuView(for: currentLight)
                        } else {
                            nav.showMenuView(for: light)
                        }
                    }
                )
                
                // Индикатор статуса лампы (недоступность по сети)
                HStack(spacing: 8) {
                    Circle()
                        .fill(itemControlViewModel.isLightReachable() ? Color.green.opacity(0) : Color.red.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text(itemControlViewModel.isLightReachable() ? "" : "Обесточена")
                        .font(Font.custom("DMSans-Medium", size: 11))
                        .foregroundStyle(itemControlViewModel.isLightReachable() ? Color.green.opacity(0.9) : Color.red.opacity(0.8))
                        .textCase(.uppercase)
                }
                .adaptiveOffset(x: -10, y: -38)
//                    Text(itemControlViewModel.getRoomName())
//                        .font(Font.custom("DMSans-Regular", size: 12))
//                        .foregroundStyle(Color.white.opacity(0.75))
//                    Text(light.metadata.name)
//                        .font(Font.custom("DMSans-Medium", size: 14))
//                        .foregroundStyle(Color.white)
//                }
                
            }
            
            // Слайдер яркости справа
            CustomSlider(
                percent: $itemControlViewModel.brightness,
                color: itemControlViewModel.dynamicColor, // ✅ Используем динамический цвет
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
            let lightService = LightControlService(appViewModel: appViewModel)
            
            // ГЛАВНОЕ ИСПРАВЛЕНИЕ: Получаем АКТУАЛЬНОЕ состояние лампы от API перед конфигурацией
            if let currentAPILight = appViewModel.lightsViewModel.lights.first(where: { $0.id == light.id }) {
                // Используем актуальное состояние лампы от API
                
                // Объединяем АКТУАЛЬНЫЕ данные от API с пользовательскими полями из БД
                var hybridLight = currentAPILight
                if let dataService = appViewModel.dataService {
                    let saved = dataService.fetchAssignedLights().first { $0.id == light.id }
                    if let saved {
                        hybridLight.metadata.userSubtypeName = saved.metadata.userSubtypeName
                        hybridLight.metadata.userSubtypeIcon = saved.metadata.userSubtypeIcon
                    }
                }
                itemControlViewModel.configure(with: lightService, light: hybridLight)
            } else {
                // Актуальное состояние лампы не найдено в API, используем переданные данные
                // Fallback к изначальной логике
                var initialLight = light
                if let dataService = appViewModel.dataService {
                    let saved = dataService.fetchAssignedLights().first { $0.id == light.id }
                    if let saved {
                        initialLight.metadata.userSubtypeName = saved.metadata.userSubtypeName
                        initialLight.metadata.userSubtypeIcon = saved.metadata.userSubtypeIcon
                    }
                }
                itemControlViewModel.configure(with: lightService, light: initialLight)
            }
            
            // Дополнительная синхронизация с БД для пользовательских полей
            loadActualLightData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LightDataUpdated"))) { notification in
            // Обновляемся только при изменениях пользовательского подтипа
            if let userInfo = notification.userInfo,
               let updateType = userInfo["updateType"] as? String,
               updateType == "userSubtype" {
                // Получено обновление userSubtype из БД
                loadActualLightData()
            }
        }
        .onChange(of: light) { newLight in
            // ✅ Просто обновляем ViewModel БЕЗ сохранения в БД
            
            // Если есть сохранённые userSubtype и иконка в БД - используем их, иначе берём из API
            if let dataService = appViewModel.dataService {
                let savedLights = dataService.fetchAssignedLights()
                if let savedLight = savedLights.first(where: { $0.id == newLight.id }) {
                    // Создаём гибридный объект: состояние из API + пользовательские подтип и иконка из БД
                    var hybridLight = newLight
                    // Переносим пользовательские поля независимо от API-архетипа
                    hybridLight.metadata.userSubtypeName = savedLight.metadata.userSubtypeName
                    hybridLight.metadata.userSubtypeIcon = savedLight.metadata.userSubtypeIcon
                    itemControlViewModel.setCurrentLight(hybridLight)
                    return
                }
            }
            
            // Если в БД нет - используем данные из API как есть
            itemControlViewModel.setCurrentLight(newLight)
        }

    }
    
    // MARK: - Private Methods
    
    /// Загрузить актуальные данные лампы из DataPersistenceService
    private func loadActualLightData() {
        
        // Получаем актуальные данные из DataPersistenceService через AppViewModel
        if let dataPersistenceService = appViewModel.dataService {
            let savedLights = dataPersistenceService.fetchAssignedLights()
            if let savedLight = savedLights.first(where: { $0.id == light.id }) {
                
                // СОЗДАЁМ ГИБРИДНЫЙ ОБЪЕКТ: пользовательские данные из БД + актуальное состояние из API
                var hybridLight = light // Начинаем с актуальных данных из API
                hybridLight.metadata.userSubtypeName = savedLight.metadata.userSubtypeName
                hybridLight.metadata.userSubtypeIcon = savedLight.metadata.userSubtypeIcon
                
                
                // Обновляем ViewModel с гибридными данными
                itemControlViewModel.setCurrentLight(hybridLight)
            } else {
                // Лампа не найдена в БД, используем данные из API
                itemControlViewModel.setCurrentLight(light)
            }
        } else {
            // DataPersistenceService недоступен, используем данные из API
            itemControlViewModel.setCurrentLight(light)
        }
    }

}

// MARK: - Mock ItemControl для превью с уникальными цветами

/// Специальный ItemControl для превью с уникальными темными цветами
struct MockItemControl: View {
    let light: Light
    let mockColor: Color
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var nav: NavigationManager
    @StateObject private var itemControlViewModel: ItemControlViewModel
    
    init(light: Light, mockColor: Color) {
        self.light = light
        self.mockColor = mockColor
        self._itemControlViewModel = StateObject(wrappedValue: ItemControlViewModel.createIsolated())
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                ControlView(
                    isOn: $itemControlViewModel.isOn,
                    baseColor: mockColor,
                    bulbName: light.metadata.name,
                    bulbType: itemControlViewModel.getBulbType(),
                    roomName: itemControlViewModel.getRoomName(),
                    bulbIcon: itemControlViewModel.getBulbIcon(),
                    roomIcon: itemControlViewModel.getRoomIcon(),
                    onToggle: { newState in
                        itemControlViewModel.setPower(newState)
                    },
                    onMenuTap: {
                        // Показываем MenuView для этой лампы (даже в Mock режиме)
                        nav.showMenuView(for: light)
                    }
                )
                
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
                    Text(itemControlViewModel.currentLight?.metadata.name ?? light.metadata.name)
                        .font(Font.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Color.white)
                }
                .adaptiveOffset(x: 40, y: -8)
                
                // Индикатор статуса лампы для Mock версии
                HStack(spacing: 8) {
                    Circle()
                        .fill(itemControlViewModel.isLightReachable() ? Color.green.opacity(0) : Color.red.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text(itemControlViewModel.isLightReachable() ? "" : "Обесточена")
                        .font(Font.custom("DMSans-Medium", size: 11))
                        .foregroundStyle(itemControlViewModel.isLightReachable() ? Color.green.opacity(0.9) : Color.red.opacity(0.8))
                        .textCase(.uppercase)
                }
                .adaptiveOffset(x: -10, y: -38)
            }
            
            CustomSlider(
                percent: $itemControlViewModel.brightness,
                color: mockColor,
                onChange: { value in
                    itemControlViewModel.setBrightnessThrottled(value)
                },
                onCommit: { value in
                    itemControlViewModel.commitBrightness(value)
                }
            )
            .padding(.leading, 10)
        }
        .onAppear {
            itemControlViewModel.configure(
                with: LightControlService(appViewModel: appViewModel),
                light: light
            )
        }
        .onChange(of: light) { newLight in
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
