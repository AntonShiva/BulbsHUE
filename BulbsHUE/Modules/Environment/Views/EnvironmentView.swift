//
//  EnvironmentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var dataPersistenceService: DataPersistenceService
    
    /// Координатор для управления лампами и комнатами (SOLID принципы)
    @State private var environmentCoordinator: EnvironmentCoordinator?
    
    var body: some View {
        if nav.currentRoute == .addRoom {
            AddNewRoom()
        } else {
        ZStack {
            BG()
            
            Header(title: "ENVIRONMENT") {
                // Левая кнопка - ваше меню
                MenuButton { }
            } rightView: {
                // Правая кнопка - плюс
                AddHeaderButton {
                    nav.go(.addNewBulb)
                }
            }
            .adaptiveOffset(y: -330)
            .onTapGesture(count: 3) {
                // Секретный triple-tap для доступа к Development меню
#if DEBUG
                nav.go(.development)
#endif
            }
            
            SelectorTabEnviromentView()
                .adaptiveOffset(y: -264)
            
            // ✅ Используем координатор с разделением ответственности (SOLID)
            if let coordinator = environmentCoordinator {
                if  nav.еnvironmentTab == .bulbs {
                    // Вкладка ламп
                    if !coordinator.hasAssignedLights {
                        EmptyBulbsLightsView {
                            nav.go(.addNewBulb)
                        }
                    } else {
                        AssignedBulbsLightsListView(
                            lights: coordinator.lightsViewModel.assignedLights,
                            onRemoveLight: { lightId in
                                coordinator.removeLightFromEnvironment(lightId)
                            }
                        )
                        .adaptiveOffset(y: 30)
                    }
                } else if nav.еnvironmentTab == .rooms {
                    // Вкладка комнат
                    if !coordinator.hasRooms {
                        EmptyRoovmsLightsView{
                            nav.currentRoute = .addRoom
                            nav.isTabBarVisible = false
                        }
                    } else {
                        AssignedRoomsListView(
                            rooms: coordinator.roomsViewModel.rooms,
                            onRemoveRoom: { roomId in
                                coordinator.removeRoom(roomId)
                            }
                        )
                        .adaptiveOffset(y: 30)
                    }
                }
            }
        }
        .onAppear {
            // ✅ SOLID: Создаем координатор через фабрику с разделением ответственности
            if appViewModel.connectionStatus == .connected {
                if environmentCoordinator == nil {
                    environmentCoordinator = EnvironmentCoordinator.create(
                        appViewModel: appViewModel,
                        dataPersistenceService: dataPersistenceService,
                        diContainer: DIContainer.shared
                    )
                }
                
                // Обновляем данные при каждом появлении экрана
                appViewModel.lightsViewModel.loadLights()
                environmentCoordinator?.refreshAll()
            } else {
                // Нет подключения - пропускаем загрузку
            }
        }
        
        .refreshable {
            // ✅ Поддержка pull-to-refresh для всех данных
            environmentCoordinator?.refreshAll()
        }
        .onChange(of: nav.еnvironmentTab) { newTab in
            // ✅ При переключении вкладок принудительно обновляем состояние
            
            // Принудительная синхронизация состояния без запроса к API
            environmentCoordinator?.forceStateSync()
            
            // Дополнительно обновляем данные из API для получения актуального состояния (если подключены)
            if appViewModel.connectionStatus == .connected {
                appViewModel.lightsViewModel.loadLights()
            }
        }
    }
    }
}

// MARK: - Subviews

/// Компонент для отображения пустого состояния
private struct EmptyBulbsLightsView: View {
    let onAddBulb: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("You don't have \nany bulbs yet")
                .font(Font.custom("DMSans-Regular", size: 16))
                .kerning(3.2)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.75, green: 0.85, blue: 1))
                .opacity(0.3)
                .textCase(.uppercase)

            AddButton(text: "add bulb", width: 427, height: 295) {
                onAddBulb()
            }
            .adaptiveOffset(y: 175)
        }
    }
}

private struct EmptyRoovmsLightsView: View {
    let onAddBulb: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
           
                Text("You don’t have \nany rooms yet")
                    .font(Font.custom("DMSans-Regular", size: 16))
                    .kerning(3.2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.75, green: 0.85, blue: 1))
                    
                    .opacity(0.3)
                
                
                AddRoomButton(text: "create room", width: 390, height: 305, image: "BGAddRoom", offsetX: 21, offsetY: -1.5) {
                    onAddBulb()
                    }
                
                .adaptiveOffset(y: 196)
            
         }
        .textCase(.uppercase)
    }
}

/// Компонент для отображения списка назначенных ламп
private struct AssignedBulbsLightsListView: View {
    let lights: [Light]
    let onRemoveLight: ((String) -> Void)?
    
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var nav: NavigationManager
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                ForEach(lights) { light in
                    // ✅ ИСПРАВЛЕНО: Используем оригинальный ItemControl с полной логикой
                    ItemControl(light: light)
                    .id("item_\(light.id)_\(light.on.on)_\(Int(light.dimming?.brightness ?? 0))") // Уникальный ID с состоянием для принудительного обновления
                    .padding(.horizontal, 10) // Дополнительные отступы для каждого элемента
                    .contextMenu {
                        Button("Убрать из Environment", role: .destructive) {
                            onRemoveLight?(light.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20) // Добавляем отступы по краям
        }
        .adaptiveOffset(y: 180)
    }
}

// MARK: - Mock Components для превью

/// Компонент для отображения списка ламп с уникальными цветами в превью
private struct MockAssignedLightsListView: View {
    let lights: [Light]
    let onRemoveLight: ((String) -> Void)?
    
    // Массив темных цветов для превью
    private let mockColors: [Color] = [
        Color(hue: 0.60, saturation: 0.8, brightness: 0.6),   // Темно-синий
        Color(hue: 0.33, saturation: 0.8, brightness: 0.5),   // Темно-зеленый  
        Color(hue: 0.83, saturation: 0.7, brightness: 0.6),   // Темно-фиолетовый
        Color(hue: 0.08, saturation: 0.9, brightness: 0.6),   // Темно-оранжевый
        Color(hue: 0.97, saturation: 0.8, brightness: 0.7),   // Темно-розовый
        Color(hue: 0.50, saturation: 0.7, brightness: 0.5),   // Темно-бирюзовый
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                ForEach(Array(lights.enumerated()), id: \.element.id) { index, light in
                    MockItemControl(
                        light: light,
                        mockColor: mockColors[index % mockColors.count]
                    )
                    .padding(.horizontal, 10)
                    .contextMenu {
                        Button("Убрать из Environment", role: .destructive) {
                            onRemoveLight?(light.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .adaptiveOffset(y: 180)
    }
}

#Preview("Environment with Mock Data") {
    EnvironmentView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .environmentObject(DataPersistenceService.createMock())
}

#Preview("Environment with Colorful Mock Lights") {
    ZStack {
        BG()
        
        Header(title: "ENVIRONMENT") {
            MenuButton { }
        } rightView: {
            AddHeaderButton { }
        }
        .adaptiveOffset(y: -330)
        
        SelectorTabEnviromentView()
            .adaptiveOffset(y: -264)
        
        // Используем MockAssignedLightsListView с цветными ItemControl
        MockAssignedLightsListView(
            lights: [
                Light(id: "mock1", type: "light", metadata: LightMetadata(name: "Living Room Ceiling", archetype: "ceiling_round"), on: OnState(on: true), dimming: Dimming(brightness: 85), color: nil, color_temperature: nil, effects: nil, effects_v2: nil, mode: nil, capabilities: nil, color_gamut_type: nil, color_gamut: nil, gradient: nil),
                Light(id: "mock2", type: "light", metadata: LightMetadata(name: "Bedroom Table Lamp", archetype: "table_shade"), on: OnState(on: false), dimming: Dimming(brightness: 0), color: nil, color_temperature: nil, effects: nil, effects_v2: nil, mode: nil, capabilities: nil, color_gamut_type: nil, color_gamut: nil, gradient: nil),
                Light(id: "mock3", type: "light", metadata: LightMetadata(name: "Kitchen Spots", archetype: "ceiling_square"), on: OnState(on: true), dimming: Dimming(brightness: 65), color: nil, color_temperature: nil, effects: nil, effects_v2: nil, mode: nil, capabilities: nil, color_gamut_type: nil, color_gamut: nil, gradient: nil),
                Light(id: "mock4", type: "light", metadata: LightMetadata(name: "Office Floor Lamp", archetype: "floor_shade"), on: OnState(on: true), dimming: Dimming(brightness: 45), color: nil, color_temperature: nil, effects: nil, effects_v2: nil, mode: nil, capabilities: nil, color_gamut_type: nil, color_gamut: nil, gradient: nil)
            ],
            onRemoveLight: nil
        )
        .adaptiveOffset(y: 30)
    }
    .environmentObject(NavigationManager.shared)
    .environmentObject(AppViewModel())
}

#Preview("Environment with Figma") {
    EnvironmentView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .environmentObject(DataPersistenceService.createMock())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=120-1187&t=B04C893qA3iLYnq6-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

#Preview("MasterView") {
    MasterView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .environmentObject(DataPersistenceService.createMock())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=B04C893qA3iLYnq6-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}


