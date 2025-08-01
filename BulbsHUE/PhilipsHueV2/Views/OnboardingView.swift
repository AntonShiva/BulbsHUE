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
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel: OnboardingViewModel
    
    init(appViewModel: AppViewModel) {
        self._viewModel = StateObject(wrappedValue: OnboardingViewModel(appViewModel: appViewModel))
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
//        .alert("Доступ к локальной сети", isPresented: $viewModel.showLocalNetworkAlert) {
//            Button("Настройки") {
//                viewModel.openAppSettings()
//            }
//            Button("Отмена", role: .cancel) { }
//        } message: {
//            Text("Для подключения к Hue Bridge необходим доступ к локальной сети. Откройте Настройки > BulbsHUE > Локальная сеть и включите доступ.")
//        }
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
        case .bridgeFound:
            bridgeFoundStepView
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
            }
            
            // Кнопки действий
            VStack(spacing: 16) {
                Button("Да") {
                    viewModel.nextStep()
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
    

    
    /// Экран разрешения локальной сети (как на четвертом скриншоте)
    private var localNetworkPermissionStepView: some View {
        VStack(spacing: 40) {
            bridgeWithRouterImageView
            
            VStack(spacing: 16) {
                Text("Подключить Hue Bridge")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Подключите блок управления Hue Bridge к питанию, затем с помощью поставляемого в комплекте кабеля соедините его со своим ")
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
                    Text(", что и ваше мобильное устройство, только в этом случае приложение Hue сможет его обнаружить.")
                        .foregroundColor(.white.opacity(0.8))
                }
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
            }
            
            VStack(spacing: 16) {
                Button("Поиск") {
                    // Переходим к следующему шагу
                    viewModel.nextStep()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Мне нужна помощь") {
                    viewModel.showLocalNetworkInfo()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 40)
        }
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
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Поиск устройств в сети...")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    Text("Нажмите 'Поиск' для обнаружения Hue Bridge в локальной сети")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            if !viewModel.isSearchingBridges {
                // Показываем разные кнопки в зависимости от того, найдены ли мосты
                if viewModel.discoveredBridges.isEmpty {
                    Button("Поиск") {
                        viewModel.startBridgeSearch()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                } else {
                    // Показываем найденные мосты и кнопку "Далее"
                    VStack(spacing: 16) {
                        // Список найденных мостов
                        ForEach(viewModel.discoveredBridges, id: \.id) { bridge in
                            HStack {
                                Image(systemName: "wifi.router")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("Hue Bridge")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text(bridge.internalipaddress)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                        }
                        
                        Button("Далее") {
                            if let bridge = viewModel.discoveredBridges.first {
                                viewModel.selectBridge(bridge)
                            }
                            viewModel.nextStep()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 40)
                    }
                }
            }
        }
        .onAppear {
            // Автоматически начинаем поиск при появлении экрана
            if !viewModel.isSearchingBridges && viewModel.discoveredBridges.isEmpty {
                viewModel.startBridgeSearch()
            }
        }
    }
    
    /// Экран найденного моста (как на пятом скриншоте)
    private var bridgeFoundStepView: some View {
        VStack(spacing: 40) {
            // Иконка с найденным мостом
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
                Text("Найден блок управления Hue.")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                
            }
            
            Button("Подключиться") {
                if let bridge = viewModel.discoveredBridges.first {
                    viewModel.selectBridge(bridge)
                }
                viewModel.nextStep()
                // Показываем алерт перед переходом к linkButton
//                viewModel.showLinkButtonAlert = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
    }
    
    /// Экран нажатия кнопки Link
    private var linkButtonStepView: some View {
        VStack(spacing: 40) {
            bridgeImageView
            
            VStack(spacing: 16) {
                Text("Подключение к мосту")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Нажмите круглую кнопку Link на вашем Hue Bridge для завершения подключения")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
             
            }
            
            Button("Отмена") {
                viewModel.cancelLinkButton()
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Автоматически начинаем процесс подключения когда появляется экран
            if viewModel.selectedBridge != nil  {
                viewModel.startBridgeConnection()
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

#Preview {
    let appViewModel = AppViewModel()
    appViewModel.showSetup = true
    
    return OnboardingView(appViewModel: appViewModel)
        .environmentObject(appViewModel)
}
