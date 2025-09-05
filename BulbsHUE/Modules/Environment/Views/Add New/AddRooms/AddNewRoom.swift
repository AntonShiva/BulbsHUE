//
//  AddNewRoom.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

struct AddNewRoom: View {
    // MARK: - Environment Dependencies
    @Environment(NavigationManager.self) private var nav
    @Environment(AppViewModel.self) private var appViewModel
    
    // MARK: - ViewModel (создается с правильными зависимостями)
    @State private var viewModel = AddNewRoomViewModel()
    
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
                    } else if viewModel.currentStep == 1 {
                        // Шаг 2: Выбор ламп
                        lightSelectionView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        // Шаг 3: Ввод названия комнаты
                        roomNameInputView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .adaptiveOffset(y: 150)
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
        VStack(spacing: 16) {
            // Индикатор поиска
            if viewModel.isSearchingLights {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.79, green: 1, blue: 1)))
                        .scaleEffect(1.2)
                    
                    Text("поиск ламп...")
                        .font(Font.custom("DMSans-Light", size: 14))
                        .kerning(2.8)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                        .textCase(.uppercase)
                }
                .adaptiveFrame(width: 332, height: 80)
                .background(Color(red: 0.79, green: 1, blue: 1).opacity(0.05))
                .cornerRadius(15)
                .transition(.opacity.combined(with: .scale))
            } else if viewModel.availableLights.isEmpty && !viewModel.isSearchingLights {
                // Сообщение что ламп нет
                VStack(spacing: 12) {
                    Text("лампы не найдены")
                        .font(Font.custom("DMSans-Light", size: 14))
                        .kerning(2.8)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                        .textCase(.uppercase)
                }
                .adaptiveFrame(width: 332, height: 80)
                .background(Color(red: 0.79, green: 1, blue: 1).opacity(0.05))
                .cornerRadius(15)
                .transition(.opacity.combined(with: .scale))
                .adaptiveOffset(y: 100)
            }
            
            // Список ламп
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
            .adaptiveFrame(height: viewModel.isSearchingLights || (viewModel.availableLights.isEmpty && !viewModel.isSearchingLights) ? 475 : 555)
        }
        .adaptiveOffset(y: 65)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isSearchingLights)
        .animation(.easeInOut(duration: 0.3), value: viewModel.availableLights.count)
    }
    
    // MARK: - Представление ввода названия комнаты
    private var roomNameInputView: some View {
        VStack(spacing: 24) {
            // Заголовок
            Text("your new room name")
                .font(Font.custom("DMSans-Regular", size: 14))
                .kerning(2.8)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .textCase(.uppercase)
                .adaptiveOffset(y: 65)
            
            // TextField для ввода названия
            ZStack {
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 332, height: 64)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .cornerRadius(15)
                    .opacity(0.1)
                
                TextField("", text: $viewModel.customRoomName)
                    .font(Font.custom("DMSans-Regular", size: 14))
                    .kerning(2.8)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .textCase(.uppercase)
                    .submitLabel(.done)
                    .onSubmit {
                        // При нажатии Done на клавиатуре - создаем комнату
                        if viewModel.isContinueButtonEnabled {
                            viewModel.handleContinueAction()
                        }
                    }
            }
            .adaptiveOffset(y: 65)
            
            Spacer()
        }
        .adaptiveFrame(height: 555)
    }
    
    // MARK: - Private Methods
    
    /// Настройка реальных зависимостей ViewModel после инициализации View
    private func setupViewModelDependencies() {
        // Устанавливаем реальные зависимости из EnvironmentObject
        viewModel.setLightsProvider(appViewModel)
        viewModel.setNavigationManager(nav)
        
        // ✅ НОВОЕ: Устанавливаем провайдер поиска ламп
        viewModel.setLightsSearchProvider(appViewModel.lightsViewModel)
        
        // Создаем сервис создания комнат с UseCase из DIContainer
        let diContainer = DIContainer.shared
        let roomCreationService = DIRoomCreationService(
            createRoomWithLightsUseCase: diContainer.createRoomWithLightsUseCase
        )
        viewModel.setRoomCreationService(roomCreationService)
        
        // Вызываем setupBindings после установки всех зависимостей
        viewModel.setupBindings()
    }
}

#Preview {
    AddNewRoom()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=39-1983&m=dev")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

#Preview {
    AddNewRoom()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=137-17&t=kP7IyE6sdigfMj6S-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
