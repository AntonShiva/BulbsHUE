//
//  AddNewRoom.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

struct AddNewRoom: View {
    @StateObject private var categoryManager = RoomCategoryManager()
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var appViewModel: AppViewModel
    
    // States для управления шагами
    @State private var currentStep: Int = 0
    @State private var selectedLights: Set<String> = [] // ID выбранных ламп
    
    var body: some View {
        ZStack {
            BGLight()
            
            HeaderAddNew(title: "NEW ROOM"){
                
                    DismissButton{
                        nav.go(.environment)
                    }
                
            }
            .adaptiveOffset(y: -323)
            
            VStack(spacing: 0) {
                
                // Контент в зависимости от шага
                Group {
                    if currentStep == 0 {
                        // Шаг 1: Выбор категории комнаты
                        categorySelectionView
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        // Шаг 2: Выбор ламп
                        lightSelectionView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                
                
                // Кнопка продолжения
                VStack {
                    Spacer()
                   
                    if shouldShowContinueButton {
                        ZStack{
                            CustomStepIndicator(currentStep: currentStep)
                                .adaptiveOffset(y: -45)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
                            
                            CustomButtonAdaptiveRoom(text: currentStep == 0 ? "continue" : "create room", width: 390, height: 266, image: "BGRename", offsetX: 2.3, offsetY: 18.8) {
                                handleContinueAction()
                            }
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                        .adaptiveOffset(y: 12)
                    }
                }
                .adaptiveFrame(height: 245)
            }
            
        }
    }
    
    // MARK: - Представление выбора категории
    private var categorySelectionView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 332, height: 64)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .cornerRadius(15)
                   .transition(.opacity.combined(with: .move(edge: .top)))
                    .opacity(0)
                
                ForEach(categoryManager.roomCategories, id: \.id) { roomCategory in
                    TupeCell(
                        roomCategory: roomCategory,
                        categoryManager: categoryManager,
                        iconWidth: 32, // Увеличенная ширина для комнат
                        iconHeight: 32 // Увеличенная высота для комнат
                    )
                }
            }
        }
        .adaptiveOffset(y: 65)
        .adaptiveFrame(height: 555)
    }
    
    // MARK: - Представление выбора ламп
    private var lightSelectionView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 332, height: 64)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .cornerRadius(15)
                   .transition(.opacity.combined(with: .move(edge: .top)))
                    .opacity(0)
                
                ForEach(availableLights, id: \.id) { light in
                    LightSelectionCell(
                        light: light,
                        isSelected: selectedLights.contains(light.id)
                    ) {
                        toggleLightSelection(light.id)
                    }
                }
            }
        }
        .adaptiveOffset(y: 65)
        .adaptiveFrame(height: 555)
    }
    
    // MARK: - Computed Properties
    private var shouldShowContinueButton: Bool {
        if currentStep == 0 {
            return categoryManager.hasSelection
        } else {
            return !selectedLights.isEmpty
        }
    }
    
    private var availableLights: [LightEntity] {
        // Конвертируем Light в LightEntity и фильтруем доступные
        return appViewModel.lightsViewModel.lights.compactMap { light in
            // Определяем тип лампы из архетипа или по умолчанию
            let lightType: LightType
            if let archetype = light.metadata.archetype?.lowercased() {
                switch archetype {
                case let type where type.contains("ceiling"):
                    lightType = .ceiling
                case let type where type.contains("floor"):
                    lightType = .floor
                case let type where type.contains("wall"):
                    lightType = .wall
                case let type where type.contains("table"), let type where type.contains("desk"):
                    lightType = .table
                default:
                    lightType = .other
                }
            } else {
                lightType = .other
            }
            
            return LightEntity(
                id: light.id,
                name: light.metadata.name,
                type: lightType,
                subtype: nil, // Пока упрощаем
                isOn: light.on.on,
                brightness: Double(light.dimming?.brightness ?? 0),
                color: light.color?.xy.map { LightColor(x: $0.x, y: $0.y) },
                colorTemperature: light.color_temperature?.mirek,
                isReachable: true, // В API v2 все лампы считаются достижимыми, если они есть в списке
                roomId: nil, // Упрощаем - считаем что все лампы доступны для назначения
                userSubtype: nil,
                userIcon: nil
            )
        }
    }
    
    // MARK: - Actions
    private func handleContinueAction() {
        if currentStep == 0 {
            // Переход к выбору ламп
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = 1
            }
        } else {
            // Создание комнаты
            createRoomWithLights()
        }
    }
    
    private func toggleLightSelection(_ lightId: String) {
        if selectedLights.contains(lightId) {
            selectedLights.remove(lightId)
        } else {
            selectedLights.insert(lightId)
        }
    }
    
    
    // MARK: - Сохранение комнаты с лампами
    private func createRoomWithLights() {
        guard let selectedSubtype = categoryManager.getSelectedSubtype() else {
            print("❌ Missing selected room subtype")
            return
        }
        
        let selectedLightEntities = availableLights.filter { selectedLights.contains($0.id) }
        
        // Здесь будет логика создания комнаты с выбранными лампами
        print("✅ Комната будет создана:")
        print("   Тип: '\(selectedSubtype.name)'")
        print("   Иконка: '\(selectedSubtype.iconName)'")
        print("   Лампы: \(selectedLightEntities.map { $0.name })")
        
        // Возвращаемся к основному экрану
        nav.go(.environment)
    }
}

#Preview {
    AddNewRoom()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=39-1983&m=dev")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

#Preview {
    AddNewRoom()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=137-17&t=kP7IyE6sdigfMj6S-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
