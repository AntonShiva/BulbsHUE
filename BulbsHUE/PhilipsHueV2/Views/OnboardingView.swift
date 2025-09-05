//
//  OnboardingView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 30.07.2025.
//

import SwiftUI
// import CodeScanner // Закомментировано - используется для QR-кода

/// Главный экран онбординга для настройки Hue Bridge
struct OnboardingView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel: OnboardingViewModel
    
    init() {
        // Initialize with temporary AppViewModel, will be configured in onAppear
        self._viewModel = State(initialValue: OnboardingViewModel(appViewModel: AppViewModel()))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фоновый градиент как на скриншотах
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.15, blue: 0.35), // Темно-синий
                        Color(red: 0.05, green: 0.1, blue: 0.25)  // Еще темнее
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Кнопка назад
                    HStack {
                        Button(action: {
                            if viewModel.currentStep != .welcome {
                                viewModel.previousStep()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                    }
                    .opacity(viewModel.currentStep == .welcome ? 0 : 1)
                    
                    Spacer()
                    
                    // Основной контент в зависимости от шага
                    contentForCurrentStep
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // 🔧 ИСПРАВЛЕНИЕ: Настраиваем OnboardingViewModel с правильным AppViewModel из Environment
                viewModel.configureAppViewModel(appViewModel)
            }
            // Также добавьте алерт для отображения процесса в главном body OnboardingView:

//            .alert("Подключение к Hue Bridge", isPresented: $viewModel.showLinkButtonAlert) {
//                if viewModel.linkButtonPressed {
//                    Button("OK") {
//                        viewModel.showLinkButtonAlert = false
//                    }
//                } else {
//                    Button("Отмена") {
//                        viewModel.cancelLinkButton()
//                    }
//                }
//            } message: {
//                if viewModel.linkButtonPressed {
//                    Text("✅ Подключение успешно установлено!")
//                } else {
//                    VStack {
//                        Text("👆 Нажмите круглую кнопку Link на верхней части вашего Hue Bridge")
//                        Text("")
//                        if viewModel.linkButtonCountdown > 0 {
//                            Text("⏱ Осталось времени: \(viewModel.linkButtonCountdown) сек")
//                        }
//                    }
//                }
//            }
        }
        // MARK: - QR Code Sheets (закомментировано)
        /*
         .sheet(isPresented: $viewModel.showQRScanner) {
         QRCodeScannerView { code in
         viewModel.handleScannedQR(code)
         }
         }
         .alert("Разрешение камеры", isPresented: $viewModel.showCameraPermissionAlert) {
         Button("Настройки") {
         viewModel.openAppSettings()
         }
         Button("Отмена", role: .cancel) { }
         } message: {
         Text("Для сканирования QR-кода необходимо разрешение на использование камеры. Откройте настройки и разрешите доступ к камере.")
         }
         */
        // Убрали лишний алерт - iOS сам покажет запрос разрешения
        // .alert("Доступ к локальной сети", isPresented: $viewModel.showLocalNetworkAlert) {
        //        .alert("Подключение к Hue Bridge", isPresented: $viewModel.showLinkButtonAlert) {
        //            Button("Готово") {
        //                viewModel.showLinkButtonAlert = false
        //                viewModel.nextStep() // Переходим к linkButtonStepView
        //            }
        //            Button("Отмена", role: .cancel) {
        //                viewModel.cancelLinkButton()
        //            }
        //        } message: {
        //            Text("Нажмите кнопку на мосту для подключения.\n\nНажмите кнопку на внешнем устройстве")
        //        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentForCurrentStep: some View {
        switch viewModel.currentStep {
        case .welcome:
            welcomeStepView
        case .localNetworkPermission:
            localNetworkPermissionStepView
        case .searchBridges:
            searchBridgesStepView
        case .linkButton:
            linkButtonStepView
        case .connected:
            connectedStepView
        }
        
        // MARK: - QR Code Steps (закомментировано)
        /*
         case .cameraPermission:
         cameraPermissionStepView
         case .qrScanner:
         // Этот экран больше не нужен - сразу открываем камеру
         EmptyView()
         */
    }
    
    // MARK: - Step Views
    
    /// Экран приветствия (как на втором скриншоте)
    private var welcomeStepView: some View {
        VStack(spacing: 40) {
            // Изображение Hue Bridge
            bridgeImageView
            
            // Заголовок и описание
            VStack(spacing: 16) {
                Text("Хотите добавить Hue Bridge?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Hue Bridge — это умный шлюз, который подключается к вашему маршрутизатору для управления системой Hue. Вы можете продолжить без него или добавить его позднее.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Новое: Разрешение на поиск в локальной сети
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "network")
                        .foregroundColor(.cyan)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Нам нужно Ваше разрешение на поиск этого устройства в вашей локальной сети.")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("После нажатия \"Поиск\" iOS может запросить разрешение на доступ к локальной сети - необходимо выбрать \"Разрешить\".")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Кнопки действий
            VStack(spacing: 16) {
                Button("Да") {
                    // Запрашиваем разрешение локальной сети на первом экране
                    viewModel.requestLocalNetworkPermissionOnWelcome()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Нет") {
                    // Пропускаем онбординг
                    appViewModel.showSetup = false
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 40)
        }
//        .alert("Нужно разрешение", isPresented: $viewModel.showPermissionAlert) {
//            Button("Перейти в Настройки") {
//                // Открываем настройки приложения
//                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
//                    UIApplication.shared.open(settingsUrl)
//                }
//            }
//            Button("Повторить") {
//                viewModel.requestLocalNetworkPermissionOnWelcome()
//            }
//            Button("Отмена", role: .cancel) { }
//        } message: {
//            Text("Для поиска Hue Bridge необходимо разрешить приложению доступ к локальной сети. Пожалуйста, выберите \"Разрешить\" в диалоге системы или перейдите в Настройки > Конфиденциальность > Локальная сеть.")
//        }
    }
    

    
    /// Экран разрешения локальной сети с предварительным запросом
    private var localNetworkPermissionStepView: some View {
        VStack(spacing: 40) {
            bridgeWithRouterImageView
            
            VStack(spacing: 16) {
                Text("Подключить Hue Bridge")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Основная инструкция
                    (Text("Подключите блок управления Hue Bridge к питанию, затем с помощью поставляемого в комплекте кабеля соедините его со своим ")
                        .foregroundColor(.white.opacity(0.8))
                     +
                     Text("маршрутизатором Wi-Fi")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                     +
                     Text(". Ваш блок управления Hue Bridge должен быть подключен ")
                        .foregroundColor(.white.opacity(0.8))
                     +
                     Text("к той же сети Wi-Fi")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                     +
                     Text(", что и ваше мобильное устройство.")
                        .foregroundColor(.white.opacity(0.8)))
                    
                  
                }
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
            }
            
            VStack(spacing: 16) {
                Button("Поиск") {
                    // Переходим к поиску (разрешение уже получено на первом экране)
                    viewModel.nextStep()
                    // Задержка для анимации перехода, затем начинаем поиск
                    Task { @MainActor in
                        try await Task.sleep(for: .milliseconds(300))
                        viewModel.startBridgeSearch()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Мне нужна помощь") {
                    viewModel.showLocalNetworkInfo()
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 40)
    }
    
    
    /// Экран поиска мостов
    private var searchBridgesStepView: some View {
        VStack(spacing: 40) {
            bridgeWithRouterImageView
            
            VStack(spacing: 16) {
                Text("Поиск Hue Bridge")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if viewModel.isSearchingBridges {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                .scaleEffect(1.2)
                            
                            Text("Поиск устройств в локальной сети...")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Text("Это может занять до 15 секунд")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else if !viewModel.discoveredBridges.isEmpty {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            Text("Найдено устройств: \(viewModel.discoveredBridges.count)")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Text("Выберите ваш Hue Bridge для подключения")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Готовы к поиску устройств")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("Убедитесь, что Hue Bridge подключен к той же сети Wi-Fi")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            if !viewModel.isSearchingBridges {
                if viewModel.discoveredBridges.isEmpty {
                    // Кнопка поиска когда мосты не найдены
                    VStack(spacing: 16) {
                        Button("Начать поиск") {
                            viewModel.startBridgeSearch()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 40)
                        
                        Button("Мне нужна помощь") {
                            viewModel.showLocalNetworkInfo()
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    // Показываем найденные мосты и кнопку "Подключиться"
                    VStack(spacing: 20) {
                        // Список найденных мостов
                        VStack(spacing: 12) {
                            ForEach(viewModel.discoveredBridges, id: \.id) { bridge in
                                HStack(spacing: 16) {
                                    Image(systemName: "wifi.router.fill")
                                        .foregroundColor(.cyan)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Philips Hue Bridge")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Text("IP: \(bridge.internalipaddress)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        if !bridge.id.isEmpty {
                                            Text("ID: \(bridge.id.prefix(8))...")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                                .onTapGesture {
                                    viewModel.selectBridge(bridge)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            Button("Подключиться") {
                                if let bridge = viewModel.discoveredBridges.first {
                                    viewModel.selectBridge(bridge)
                                }
                                viewModel.nextStep()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal, 40)
                            
                            Button("Повторить поиск") {
                                viewModel.startBridgeSearch()
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
        .onAppear {
            // Автоматически запускаем поиск при появлении экрана searchBridges
            if !viewModel.isSearchingBridges && viewModel.discoveredBridges.isEmpty {
                print("📱 SearchBridges экран появился - запускаем автоматический поиск")
                Task { @MainActor in
                    try await Task.sleep(for: .milliseconds(500))
                    viewModel.startBridgeSearch()
                }
            }
        }
    }
    
    // Удалено: экран найденного моста больше не используется
    
    /// Экран нажатия кнопки Link с правильным ожиданием
    private var linkButtonStepView: some View {
        VStack(spacing: 40) {
            // Анимированное изображение моста
            ZStack {
                bridgeImageView
                
                // Пульсирующее кольцо вокруг кнопки Link
                if viewModel.isConnecting && !viewModel.linkButtonPressed {
                    Circle()
                        .stroke(Color.cyan, lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .scaleEffect(viewModel.isConnecting ? 1.3 : 1.0)
                        .opacity(viewModel.isConnecting ? 0.3 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: viewModel.isConnecting
                        )
                        .offset(y: 30) // Позиционируем на кнопке Link
                }
                
                // Индикатор успеха
                if viewModel.linkButtonPressed {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                                .background(Color.white.clipShape(Circle()))
                        }
                        Spacer()
                    }
                    .frame(width: 120, height: 120)
                    .offset(x: 30, y: -30)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(), value: viewModel.linkButtonPressed)
                }
            }
            
            VStack(spacing: 16) {
                if viewModel.linkButtonPressed {
                    // Успешное подключение
                    Text("Подключение установлено!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .transition(.opacity)
                    
                    Text("Hue Bridge успешно подключен к приложению")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                } else if viewModel.isConnecting {
                    // Процесс ожидания
                    Text("Ожидание подключения")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        // Инструкция с анимацией
                        HStack(spacing: 8) {
                            Image(systemName: "hand.point.up.fill")
                                .foregroundColor(.cyan)
                                .font(.title3)
                                .symbolEffect(.pulse, value: viewModel.isConnecting)
                            
                            Text("Нажмите круглую кнопку Link")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Text("на верхней части вашего Hue Bridge")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Обратный отсчет
                        if viewModel.linkButtonCountdown > 0 {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                
                                Text("Осталось: \(viewModel.linkButtonCountdown) сек")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                } else if let error = viewModel.connectionError {
                    // Ошибка подключения
                    Text("Ошибка подключения")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                } else {
                    // Начальное состояние
                    Text("Подключение к мосту")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Для завершения настройки необходимо физическое подтверждение")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            // Кнопки действий
            VStack(spacing: 16) {
                if viewModel.linkButtonPressed {
                    // Кнопка продолжения после успешного подключения
                    Button("Далее") {
                        viewModel.nextStep()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .transition(.opacity)
                    
                } else if viewModel.isConnecting {
                    // Кнопка отмены во время ожидания
                    Button("Отмена") {
                        viewModel.cancelLinkButton()
                        viewModel.previousStep()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                } else if viewModel.connectionError != nil {
                    // Кнопки после ошибки
                    Button("Повторить попытку") {
                        viewModel.connectionError = nil
                        viewModel.startBridgeConnection()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Назад") {
                        viewModel.connectionError = nil
                        viewModel.previousStep()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                } else {
                    // Начальная кнопка для запуска процесса
                    Button("Начать подключение") {
                        viewModel.startBridgeConnection()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Назад") {
                        viewModel.previousStep()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 40)
            .animation(.easeInOut, value: viewModel.linkButtonPressed)
            .animation(.easeInOut, value: viewModel.isConnecting)
        }
        .onAppear {
            // Автоматически начинаем процесс подключения при появлении экрана
            if viewModel.selectedBridge != nil && !viewModel.isConnecting {
                // Небольшая задержка для плавности анимации
                Task { @MainActor in
                    try await Task.sleep(for: .milliseconds(500))
                    viewModel.startBridgeConnection()
                }
            }
        }
        .onDisappear {
            // Если уходим с экрана - отменяем подключение
            if viewModel.isConnecting && !viewModel.linkButtonPressed {
                viewModel.cancelLinkButton()
            }
        }
    }
    
    /// Экран успешного подключения (как на седьмом скриншоте)
    private var connectedStepView: some View {
        VStack(spacing: 40) {
            // Иконка с подключенным мостом
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 200, height: 200)
                
                bridgeImageView
                    .scaleEffect(0.8)
                
                // Зеленая галочка
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                            .background(Color.white.clipShape(Circle()))
                    }
                    Spacer()
                }
                .frame(width: 200, height: 200)
                .offset(x: 30, y: -30)
            }
            
            VStack(spacing: 16) {
                Text("Подключен блок управления Hue")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Ваш Hue Bridge успешно подключен к приложению. Теперь вы можете управлять освещением!")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button("Далее") {
                viewModel.nextStep() // Завершаем онбординг
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Helper Views
    
    /// Изображение Hue Bridge (белый квадрат с тремя точками и кольцом)
    private var bridgeImageView: some View {
        ZStack {
            // Основное тело моста
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 20) {
                // Три индикаторные точки
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.cyan.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.cyan.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
                
                // Кнопка Link (кольцо)
                Circle()
                    .stroke(Color.cyan, lineWidth: 3)
                    .frame(width: 40, height: 40)
            }
        }
    }
    
    /// Изображение Hue Bridge с роутером (для экранов подключения)
    private var bridgeWithRouterImageView: some View {
        HStack(spacing: 30) {
            // Hue Bridge
            bridgeImageView
            
            // Роутер (упрощенное изображение)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 60, height: 40)
                
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 30, height: 2)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 20, height: 8)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 30, height: 2)
                }
            }
            
            // Кабель (волнистая линия)
            Path { path in
                path.move(to: CGPoint(x: 0, y: 20))
                path.addQuadCurve(to: CGPoint(x: 30, y: 20), control: CGPoint(x: 15, y: 10))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 2)
            .frame(width: 30, height: 40)
        }
    }
    
}
// MARK: - Button Styles

/// Стиль вторичной кнопки (прозрачная с обводкой)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.clear)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}



// MARK: - Preview

//#Preview {
//    let appViewModel = AppViewModel(dataPersistenceService: nil)
//    appViewModel.showSetup = true
//    
//    OnboardingView(appViewModel: appViewModel)
//        .environment(appViewModel)
//}
// Стили кнопок из OnboardingView для консистентности
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}


// MARK: - QR Camera Permission Step (закомментировано)
/*
 /// Экран разрешения камеры (как на третьем скриншоте)
 private var cameraPermissionStepView: some View {
 VStack(spacing: 40) {
 bridgeImageView
 
 VStack(spacing: 16) {
 Text("Приложение «Hue» запрашивает доступ к камере.")
 .font(.title3)
 .fontWeight(.semibold)
 .foregroundColor(.white)
 .multilineTextAlignment(.center)
 
 Text("Приложение будет использовать вашу камеру для сканирования QR-кодов, использования дополненной реальности и т. д.")
 .font(.body)
 .foregroundColor(.white.opacity(0.8))
 .multilineTextAlignment(.center)
 .padding(.horizontal, 20)
 }
 
 VStack(spacing: 16) {
 Button("Разрешить") {
 viewModel.requestCameraPermission()
 }
 .buttonStyle(PrimaryButtonStyle())
 
 Button("Не разрешать") {
 viewModel.showCameraPermissionAlert = true
 }
 .buttonStyle(SecondaryButtonStyle())
 }
 .padding(.horizontal, 40)
 }
 }
 */

// Файл: BulbsHUE/PhilipsHueV2/Views/OnboardingView.swift
// Обновите метод linkButtonStepView (примерно строка 600)




