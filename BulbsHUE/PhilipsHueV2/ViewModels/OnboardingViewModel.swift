//
//  OnboardingViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 30.07.2025.

import SwiftUI
import AVFoundation
import Combine

/// ViewModel для OnboardingView с правильной обработкой Link Button
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentStep: OnboardingStep = .welcome
    @Published var showLocalNetworkAlert = false
    @Published var showPermissionAlert = false
    @Published var showLinkButtonAlert = false
    @Published var isSearchingBridges = false
    @Published var linkButtonCountdown = 30
    @Published var discoveredBridges: [Bridge] = []
    @Published var selectedBridge: Bridge?
    @Published var isConnecting = false
    @Published var isRequestingPermission = false
    @Published var linkButtonPressed = false // Флаг нажатия кнопки
    @Published var connectionError: String? = nil // Сообщение об ошибке
    
    // MARK: - Private Properties
    
    private var appViewModel: AppViewModel
    private var linkButtonTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 30 // 30 попыток * 2 сек = 60 сек максимум
    
    // MARK: - Initialization
    
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Слушаем изменения статуса подключения
        appViewModel.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                switch status {
                case .connected:
                    print("✅ OnboardingViewModel: Подключение успешно установлено!")
                    self.handleSuccessfulConnection()
                    
                case .discovered:
                    if !self.discoveredBridges.isEmpty {
                        print("📡 OnboardingViewModel: Мосты обнаружены")
                        // Не переходим автоматически, ждем действия пользователя
                    }
                    
                case .needsAuthentication:
                    print("🔐 OnboardingViewModel: Требуется авторизация (нажатие Link Button)")
                    // Остаемся на экране Link Button
                    
                case .disconnected:
                    print("❌ OnboardingViewModel: Отключено")
                    
                case .searching:
                    print("🔍 OnboardingViewModel: Поиск мостов...")
                    
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Слушаем найденные мосты
        appViewModel.$discoveredBridges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bridges in
                self?.discoveredBridges = bridges
                if !bridges.isEmpty && self?.currentStep == .searchBridges {
                    print("✅ Получены мосты от AppViewModel: \(bridges.count)")
                    
                    // Автоматически выбираем первый мост если он единственный
                    if bridges.count == 1 {
                        print("🎯 Автоматически выбираем единственный найденный мост")
                        self?.selectBridge(bridges[0])
                    }
                }
            }
            .store(in: &cancellables)
        
        // Слушаем ошибки подключения
        appViewModel.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let hueError = error as? HueAPIError {
                    self?.handleConnectionError(hueError)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .localNetworkPermission
        case .localNetworkPermission:
            currentStep = .searchBridges
        case .searchBridges:
            if !discoveredBridges.isEmpty {
                currentStep = .bridgeFound
            }
        case .bridgeFound:
            // Переходим к экрану Link Button и запускаем процесс подключения
            currentStep = .linkButton
        case .linkButton:
            // Не переходим автоматически - ждем успешного подключения
            break
        case .connected:
            // Завершаем онбординг
            appViewModel.showSetup = false
        }
    }
    
    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .localNetworkPermission:
            currentStep = .welcome
        case .searchBridges:
            currentStep = .localNetworkPermission
        case .bridgeFound:
            currentStep = .searchBridges
        case .linkButton:
            // При возврате отменяем попытки подключения
            cancelLinkButton()
            currentStep = .bridgeFound
        case .connected:
            currentStep = .linkButton
        }
    }
    
    // MARK: - Connection Management
    
    /// Запускает процесс подключения к выбранному мосту
    func startBridgeConnection() {
        guard let bridge = selectedBridge else {
            print("❌ Не выбран мост для подключения")
            return
        }
        
        // Защита от повторных вызовов
        guard !isConnecting else {
            print("⚠️ Подключение уже в процессе")
            return
        }
        
        print("🔗 Начинаем подключение к мосту: \(bridge.id) at \(bridge.internalipaddress)")
        isConnecting = true
        connectionAttempts = 0
        linkButtonPressed = false
        connectionError = nil
        
        // Сначала подключаемся к мосту (устанавливаем соединение)
        appViewModel.connectToBridge(bridge)
        
        // Показываем инструкцию о нажатии кнопки Link
        showLinkButtonAlert = true
        
        // Запускаем таймер для периодических попыток создания пользователя
        startLinkButtonPolling()
    }
    
    /// Запускает периодическую проверку нажатия Link Button
    private func startLinkButtonPolling() {
        print("⏱ Запускаем опрос Link Button каждые 2 секунды")
        
        // Отменяем предыдущий таймер если есть
        linkButtonTimer?.invalidate()
        
        // Создаем новый таймер для опроса каждые 2 секунды
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.attemptCreateUser()
        }
        
        // Первая попытка сразу
        attemptCreateUser()
    }
    
    /// Попытка создать пользователя (проверка нажатия Link Button)
    private func attemptCreateUser() {
        connectionAttempts += 1
        
        print("🔐 Попытка #\(connectionAttempts) создания пользователя...")
        
        // Проверяем лимит попыток
        if connectionAttempts >= maxConnectionAttempts {
            print("⏰ Превышен лимит попыток подключения")
            handleConnectionTimeout()
            return
        }
        
        // Обновляем обратный отсчет
        linkButtonCountdown = max(0, 60 - (connectionAttempts * 2))
        
        // Пробуем создать пользователя
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        
        appViewModel.createUserWithRetry(appName: "BulbsHUE") { [weak self] success in
            guard let self = self else { return }
            
            if success {
                print("✅ Пользователь успешно создан! Link Button был нажат!")
                self.linkButtonPressed = true
                self.handleSuccessfulConnection()
            } else {
                // Проверяем тип ошибки
                if let error = self.appViewModel.error as? HueAPIError {
                    switch error {
                    case .linkButtonNotPressed:
                        // Это нормально - кнопка еще не нажата, продолжаем опрос
                        print("⏳ Link Button еще не нажат, продолжаем ожидание...")
                        
                    case .localNetworkPermissionDenied:
                        print("🚫 Нет доступа к локальной сети!")
                        self.handleNetworkPermissionError()
                        
                    default:
                        print("❌ Ошибка при создании пользователя: \(error)")
                        // Продолжаем попытки для других ошибок
                    }
                }
            }
        }
    }
    
    /// Обработка успешного подключения
    private func handleSuccessfulConnection() {
        print("🎉 Подключение успешно установлено!")
        
        // Останавливаем таймер
        linkButtonTimer?.invalidate()
        linkButtonTimer = nil
        
        // Сбрасываем флаги
        isConnecting = false
        showLinkButtonAlert = false
        linkButtonPressed = true
        connectionError = nil
        
        // Переходим к экрану успешного подключения
        currentStep = .connected
        
        // Закрываем онбординг через секунду
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.appViewModel.showSetup = false
        }
    }
    
    /// Обработка таймаута подключения
    private func handleConnectionTimeout() {
        print("⏰ Время ожидания истекло")
        
        cancelLinkButton()
        
        connectionError = "Время ожидания истекло. Убедитесь, что вы нажали круглую кнопку Link на Hue Bridge и попробуйте снова."
        
        // Показываем ошибку пользователю
        showLinkButtonAlert = false
    }
    
    /// Обработка ошибки доступа к локальной сети
    private func handleNetworkPermissionError() {
        cancelLinkButton()
        showLocalNetworkAlert = true
    }
    
    /// Обработка ошибок подключения
    private func handleConnectionError(_ error: HueAPIError) {
        switch error {
        case .linkButtonNotPressed:
            // Игнорируем - это нормальное состояние до нажатия кнопки
            break
            
        case .localNetworkPermissionDenied:
            connectionError = "Нет доступа к локальной сети. Разрешите доступ в настройках."
            
        case .bridgeNotFound:
            connectionError = "Hue Bridge не найден в сети."
            
        case .notAuthenticated:
            connectionError = "Ошибка авторизации. Попробуйте снова."
            
        default:
            connectionError = "Ошибка подключения: \(error.localizedDescription)"
        }
    }
    
    /// Отмена процесса подключения
    func cancelLinkButton() {
        print("🚫 Отмена процесса подключения")
        
        linkButtonTimer?.invalidate()
        linkButtonTimer = nil
        showLinkButtonAlert = false
        isConnecting = false
        linkButtonPressed = false
        connectionAttempts = 0
        linkButtonCountdown = 30
        connectionError = nil
    }
    
    // MARK: - Bridge Selection
    
    func selectBridge(_ bridge: Bridge) {
        print("📡 Выбран мост: \(bridge.id)")
        selectedBridge = bridge
        appViewModel.currentBridge = bridge
    }
    
    // MARK: - Bridge Search
    
    func startBridgeSearch() {
        print("🔍 Начинаем поиск мостов в сети")
        isSearchingBridges = true
        discoveredBridges.removeAll()
        connectionError = nil
        
        appViewModel.searchForBridges()
        
        // Таймаут поиска
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            
            // Проверяем не подключились ли мы уже к мосту
            if self.appViewModel.connectionStatus == .connected ||
               self.appViewModel.connectionStatus == .needsAuthentication {
                print("✅ Мост уже найден и подключен")
                return
            }
            
            self.isSearchingBridges = false
            
            if let error = self.appViewModel.error as? HueAPIError,
               case .localNetworkPermissionDenied = error {
                print("🚫 Отказано в разрешении локальной сети")
                self.showLocalNetworkAlert = true
            } else if self.discoveredBridges.isEmpty {
                print("❌ Мосты не найдены")
                self.connectionError = "Мосты не найдены в локальной сети. Проверьте подключение."
            } else {
                print("✅ Найдено мостов: \(self.discoveredBridges.count)")
            }
        }
    }
    
    // MARK: - Local Network Permission
    
    func requestLocalNetworkPermissionOnWelcome() {
        guard !isRequestingPermission else {
            print("⚠️ Запрос разрешения уже выполняется")
            return
        }
        
        print("🔍 Запрашиваем разрешение на локальную сеть...")
        isRequestingPermission = true
        
        Task {
            do {
                let checker = LocalNetworkPermissionChecker()
                let granted = try await checker.requestAuthorization()
                
                await MainActor.run {
                    isRequestingPermission = false
                    
                    if granted {
                        print("✅ Разрешение на локальную сеть получено")
                        nextStep()
                    } else {
                        print("❌ Разрешение на локальную сеть отклонено")
                        showPermissionAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    print("❌ Ошибка при запросе разрешения: \(error)")
                    showPermissionAlert = true
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func showLocalNetworkInfo() {
        showLocalNetworkAlert = true
    }

    /// Универсальный показ ошибки (для совместимости с расширениями)
    func showGenericErrorAlert(_ message: String? = nil) {
        connectionError = message ?? "Произошла ошибка. Попробуйте ещё раз."
        showLinkButtonAlert = false
    }
}


extension OnboardingViewModel {
    
    /// Улучшенная попытка создания пользователя
    func attemptCreateUserImproved() {
        // Проверяем - может пользователь уже создан
        if appViewModel.connectionStatus == .connected {
            print("✅ Пользователь уже создан - останавливаем улучшенные попытки")
            cancelLinkButton()
            return
        }
        
        guard let bridge = selectedBridge else {
            print("❌ Не выбран мост для подключения")
            return
        }
        
        print("🔐 Попытка авторизации на мосту \(bridge.internalipaddress)...")
        
        appViewModel.createUserWithRetry(appName: "BulbsHUE") { [weak self] success in
            if success {
                print("✅ Авторизация успешна!")
                self?.cancelLinkButton()
                self?.currentStep = .connected
                
                // Закрываем онбординг через секунду
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.appViewModel.showSetup = false
                }
            } else {
                // Продолжаем попытки - кнопка Link может быть еще не нажата
                // Таймер продолжит вызывать этот метод
            }
        }
    }
}
extension OnboardingViewModel {
    
    /// Запускает процесс подключения с проверкой разрешений
    func startBridgeConnectionWithPermissionCheck() {
        guard let bridge = selectedBridge else {
            print("❌ Не выбран мост для подключения")
            return
        }
        
        print("🔗 Проверяем разрешение локальной сети...")
        
        if #available(iOS 14.0, *) {
            let checker = LocalNetworkPermissionChecker()
            Task {
                do {
                    let hasPermission = try await checker.requestAuthorization()
                    await MainActor.run {
                        if hasPermission {
                            print("✅ Разрешение локальной сети получено")
                            self.proceedWithConnection(bridge: bridge)
                        } else {
                            print("🚫 Нет разрешения локальной сети")
                            self.showLocalNetworkAlert = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Ошибка при запросе разрешения: \(error)")
                        self.showLocalNetworkAlert = true
                    }
                }
            }
        } else {
            // Для iOS < 14 сразу пытаемся подключиться
            proceedWithConnection(bridge: bridge)
        }
    }
    
    private func proceedWithConnection(bridge: Bridge) {
        print("🔗 Начинаем подключение к мосту: \(bridge.id) at \(bridge.internalipaddress)")
        currentStep = .linkButton
        showLinkButtonAlert = true
        
        // Подключаемся к мосту
        appViewModel.connectToBridge(bridge)
        
        // Запускаем таймер для попыток авторизации
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.attemptCreateUserImproved()
        }
    }
}
// MARK: - OnboardingStep

enum OnboardingStep {
    case welcome
    // MARK: - QR Code Steps (закомментировано - может понадобиться в будущем)
    // case cameraPermission
    // case qrScanner
    case localNetworkPermission
    case searchBridges
    case bridgeFound
    case linkButton
    case connected
}

// Файл: BulbsHUE/PhilipsHueV2/ViewModels/OnboardingViewModel+Fixed.swift
// ИСПРАВЛЕНИЕ: Правильная обработка Link Button в OnboardingViewModel


extension OnboardingViewModel {
    
    /// ИСПРАВЛЕННЫЙ метод запуска процесса подключения
    func startBridgeConnectionFixed() {
        guard let bridge = selectedBridge else {
            print("❌ Не выбран мост для подключения")
            connectionError = "Не выбран мост для подключения"
            return
        }
        
        // Защита от повторных вызовов
        guard !isConnecting else {
            print("⚠️ Подключение уже в процессе")
            return
        }
        
        print("🔗 Начинаем ИСПРАВЛЕННОЕ подключение к мосту: \(bridge.id)")
        
        // Устанавливаем состояние
        isConnecting = true
        connectionAttempts = 0
        linkButtonPressed = false
        connectionError = nil
        linkButtonCountdown = 60
        
        // Сначала подключаемся к мосту (проверяем доступность)
        appViewModel.connectToBridge(bridge)
        
        // Запускаем процесс с правильным обработчиком
        appViewModel.createUserWithLinkButtonHandling(
            appName: "BulbsHUE",
            onProgress: { [weak self] state in
                self?.handleLinkButtonState(state)
            },
            completion: { [weak self] result in
                self?.handleConnectionResult(result)
            }
        )
    }
    
    /// Обработчик состояний Link Button
    private func handleLinkButtonState(_ state: LinkButtonState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .idle:
                print("🔄 Link Button: Готов к подключению")
                self.isConnecting = false
                self.connectionAttempts = 0
                
            case .waiting(let attempt, let maxAttempts):
                print("⏳ Link Button: Ожидание нажатия (попытка \(attempt)/\(maxAttempts))")
                self.isConnecting = true
                self.connectionAttempts = attempt
                self.linkButtonCountdown = Swift.max(0, (maxAttempts - attempt) * 2) // 2 секунды на попытку
                
                // Обновляем UI с информацией о прогрессе
                if !self.showLinkButtonAlert {
                    self.showLinkButtonAlert = true
                }
                
            case .success:
                print("✅ Link Button: УСПЕШНОЕ ПОДКЛЮЧЕНИЕ!")
                self.isConnecting = false
                self.linkButtonPressed = true
                self.showLinkButtonAlert = false
                self.connectionError = nil
                
                // Переходим к экрану успеха
                self.currentStep = .connected
                
                // Закрываем онбординг через секунду
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.appViewModel.showSetup = false
                }
                
            case .error(let message):
                print("❌ Link Button: Ошибка - \(message)")
                self.isConnecting = false
                self.connectionError = message
                self.showLinkButtonAlert = false
                
            case .timeout:
                print("⏰ Link Button: Таймаут")
                self.isConnecting = false
                self.connectionError = "Время ожидания истекло. Убедитесь, что вы нажали кнопку Link на мосту."
                self.showLinkButtonAlert = false
            }
        }
    }
    
    /// Обработчик результата подключения
    private func handleConnectionResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch result {
            case .success(let username):
                print("🎉 Успешное подключение! Username: \(username)")
                self.linkButtonPressed = true
                self.isConnecting = false
                self.connectionError = nil
                
            case .failure(let error):
                print("❌ Ошибка подключения: \(error)")
                self.isConnecting = false
                
                if let linkError = error as? LinkButtonError {
                    switch linkError {
                    case .timeout:
                        self.connectionError = "Время ожидания истекло (60 секунд). Попробуйте снова и убедитесь, что нажали кнопку Link."
                    case .localNetworkDenied:
                        self.connectionError = "Нет доступа к локальной сети. Разрешите доступ в настройках iOS."
                        self.showLocalNetworkAlert = true
                    case .bridgeUnavailable:
                        self.connectionError = "Мост недоступен. Проверьте подключение к сети."
                    default:
                        self.connectionError = linkError.localizedDescription
                    }
                } else {
                    self.connectionError = error.localizedDescription
                }
            }
        }
    }
    
    /// Отмена процесса с правильной очисткой
    func cancelLinkButtonFixed() {
        print("🚫 Отмена процесса Link Button")
        
        isConnecting = false
        linkButtonPressed = false
        connectionAttempts = 0
        linkButtonCountdown = 60
        connectionError = nil
        showLinkButtonAlert = false
        
        // Здесь нужно добавить отмену таймера в AppViewModel если необходимо
    }
}

// MARK: - UI Helpers

extension OnboardingViewModel {
    
    /// Получить текст для отображения состояния
    var linkButtonStatusText: String {
        if linkButtonPressed {
            return "✅ Подключение установлено!"
        } else if isConnecting {
            if connectionAttempts > 0 {
                return "Попытка \(connectionAttempts) из 30..."
            } else {
                return "Ожидание нажатия кнопки Link..."
            }
        } else if let error = connectionError {
            return error
        } else {
            return "Готов к подключению"
        }
    }
    
    /// Получить цвет для индикатора состояния
    var linkButtonStatusColor: Color {
        if linkButtonPressed {
            return .green
        } else if connectionError != nil {
            return .red
        } else if isConnecting {
            return .cyan
        } else {
            return .gray
        }
    }
    
    /// Проверка готовности к следующему шагу
    var canProceedFromLinkButton: Bool {
        return linkButtonPressed && !isConnecting
    }
}

// MARK: - Camera Permission (закомментировано - может понадобиться для QR-кода в будущем)
/*
func requestCameraPermission() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        print("📷 Камера уже авторизована, открываем сканер")
        showQRScanner = true
    case .notDetermined:
        print("📷 Запрашиваем разрешение камеры")
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Разрешение камеры получено")
                    self?.showQRScanner = true
                } else {
                    print("❌ Разрешение камеры отклонено")
                    self?.showCameraPermissionAlert = true
                }
            }
        }
    case .denied, .restricted:
        print("❌ Камера запрещена или ограничена")
        showCameraPermissionAlert = true
    @unknown default:
        break
    }
}
*/

// MARK: - QR Code Handling (закомментировано - может понадобиться в будущем)
/*
func handleScannedQR(_ code: String) {
    print("📱 OnboardingViewModel: Получен QR-код: '\(code)'")
    showQRScanner = false
    
    let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Проверяем различные форматы QR-кодов Hue Bridge
    if cleanedCode.hasPrefix("bridge-id:") {
        // Основной формат Philips Hue: bridge-id:ECB5FAFFFE896811
        print("✅ Распознан QR-код Philips Hue Bridge")
        if let bridgeId = parseBridgeId(from: code) {
            print("✅ Bridge ID успешно извлечен: \(bridgeId)")
            searchForSpecificBridge(bridgeId: bridgeId)
        } else {
            print("⚠️ Не удалось извлечь Bridge ID, выполняем общий поиск")
            startBridgeSearch()
        }
        currentStep = .searchBridges
        
    } else if cleanedCode.hasPrefix("S#") {
        // Альтернативный формат: S#12345678
        print("✅ Распознан альтернативный QR-код Hue Bridge")
        let serialNumber = String(cleanedCode.dropFirst(2))
        searchForSpecificBridge(bridgeId: serialNumber)
        currentStep = .searchBridges
        
    } else if cleanedCode.hasPrefix("X-HM://") {
        // HomeKit QR-код - НЕ Philips Hue
        print("❌ Распознан HomeKit QR-код, но это не Philips Hue Bridge")
        print("💡 QR-код рядом с HomeKit меткой предназначен для подключения к HomeKit")
        print("💡 Для подключения к Hue используется поиск мостов в локальной сети")
        
        // Переходим сразу к поиску без QR-кода - мост находится в той же сети
        print("🔍 Выполняем поиск Hue Bridge в локальной сети...")
        currentStep = .searchBridges
        startBridgeSearch()
        
    } else {
        print("❌ Неизвестный формат QR-кода: \(cleanedCode)")
        print("💡 Продолжаем с поиском мостов в локальной сети")
        
        // Переходим к сетевому поиску
        print("🔍 Выполняем поиск Hue Bridge в локальной сети...")
        currentStep = .searchBridges
        startBridgeSearch()
    }
}
/// Парсинг ID моста из QR-кода
private func parseBridgeId(from input: String) -> String? {
    let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
    
    print("🔍 Парсинг QR-кода: '\(cleaned)'")
    
    // ГЛАВНЫЙ ФОРМАТ с фото: bridge-id:ECB5FAFFFE896811
    if cleaned.hasPrefix("bridge-id:") {
        let bridgeId = String(cleaned.dropFirst(10)).trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ Извлечен Bridge ID из 'bridge-id:' формата: \(bridgeId)")
        return bridgeId.uppercased()
    }
    
    // Альтернативные форматы с bridge-id
    if cleaned.contains("bridge-id") {
        let patterns = [
            #"bridge-id:\s*([A-Fa-f0-9]{12,16})"#,
            #"bridge-id\s+([A-Fa-f0-9]{12,16})"#,
            #"bridge-id\s*:\s*([A-Fa-f0-9]{12,16})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.count)),
               let range = Range(match.range(at: 1), in: cleaned) {
                let bridgeId = String(cleaned[range])
                print("✅ Извлечен Bridge ID через regex: \(bridgeId)")
                return bridgeId.uppercased()
            }
        }
    }
    
    // Если ничего не подошло, ищем hex последовательность
    let hexPattern = #"[A-Fa-f0-9]{12,16}"#
    if let regex = try? NSRegularExpression(pattern: hexPattern, options: []),
       let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.count)),
       let range = Range(match.range, in: cleaned) {
        let bridgeId = String(cleaned[range])
        print("✅ Найден возможный Bridge ID (hex): \(bridgeId)")
        return bridgeId.uppercased()
    }
    
    print("❌ Не удалось извлечь Bridge ID из: '\(cleaned)'")
    return nil
}
*/
