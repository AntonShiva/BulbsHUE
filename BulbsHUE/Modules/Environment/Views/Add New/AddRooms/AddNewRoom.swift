//
//  AddNewRoom.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

struct AddNewRoom: View {
    // MARK: - Environment Dependencies
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var appViewModel: AppViewModel
    
    // MARK: - ViewModel (создается с правильными зависимостями)
    @StateObject private var viewModel = AddNewRoomViewModel()
    
    var body: some View {
        ZStack {
            BGLight()
            
            HeaderAddNew(title: "NEW ROOM") {
                DismissButton {
                    viewModel.cancelRoomCreation()
                }
            }
            .adaptiveOffset(y: -323)
            
            VStack(spacing: 0) {
                
                // Контент в зависимости от шага ViewModel
                Group {
                    if viewModel.currentStep == 0 {
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
                
                // Кнопка продолжения с поддержкой активности
                VStack {
                    Spacer()
                    
                    ZStack {
                        CustomStepIndicator(currentStep: viewModel.currentStep)
                            .adaptiveOffset(y: -45)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
                        
                        CustomButtonAdaptiveRoom(
                            text: viewModel.continueButtonText,
                            width: 390,
                            height: 266,
                            image: "BGRename",
                            offsetX: 2.3,
                            offsetY: 18.8,
                            isEnabled: viewModel.isContinueButtonEnabled
                        ) {
                            viewModel.handleContinueAction()
                        }
                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
                    }
                    .adaptiveOffset(y: 12)
                }
                .adaptiveFrame(height: 245)
            }
        }
        .onAppear {
            // Устанавливаем реальные зависимости при появлении View
            setupViewModelDependencies()
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
                
                ForEach(viewModel.categoryManager.roomCategories, id: \.id) { roomCategory in
                    TupeCell(
                        roomCategory: roomCategory,
                        categoryManager: viewModel.categoryManager,
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

                ForEach(viewModel.availableLights, id: \.id) { light in
                    LightSelectionCell(
                        light: light,
                        isSelected: viewModel.isLightSelected(light.id)
                    ) {
                        viewModel.toggleLightSelection(light.id)
                    }
                }
            }
        }
        .adaptiveOffset(y: 65)
        .adaptiveFrame(height: 555)
    }
    
    // MARK: - Private Methods
    
    /// Настройка реальных зависимостей ViewModel после инициализации View
    private func setupViewModelDependencies() {
        // Устанавливаем реальные зависимости из EnvironmentObject
        viewModel.setLightsProvider(appViewModel)
        viewModel.setNavigationManager(nav)
        
        // Создаем сервис создания комнат с UseCase из DIContainer
        let diContainer = DIContainer.shared
        let roomCreationService = DIRoomCreationService(
            createRoomWithLightsUseCase: diContainer.createRoomWithLightsUseCase
        )
        viewModel.setRoomCreationService(roomCreationService)
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
