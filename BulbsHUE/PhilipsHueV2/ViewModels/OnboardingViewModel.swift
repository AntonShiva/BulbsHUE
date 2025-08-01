//
//  OnboardingViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 30.07.2025.
//

import SwiftUI
import AVFoundation
import Combine

/// ViewModel для OnboardingView
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentStep: OnboardingStep = .welcome
    // MARK: - QR Code Properties (закомментировано)
    // @Published var showQRScanner = false
    // @Published var showCameraPermissionAlert = false
    @Published var showLocalNetworkAlert = false
    @Published var showLinkButtonAlert = false
    @Published var isSearchingBridges = false
    @Published var linkButtonCountdown = 30
    @Published var discoveredBridges: [Bridge] = []
    @Published var selectedBridge: Bridge?
    
    // MARK: - Private Properties
    
    private var appViewModel: AppViewModel
    private var linkButtonTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
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
                switch status {
                case .connected:
                    self?.currentStep = .connected
                case .discovered:
                    if !(self?.discoveredBridges.isEmpty ?? true) {
                        self?.currentStep = .bridgeFound
                    }
                default:
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
                    for bridge in bridges {
                        print("  📡 Мост: \(bridge.id) at \(bridge.internalipaddress)")
                    }
                    
                    // Не переходим автоматически к bridgeFound - остаемся на searchBridges
                    // и показываем кнопку "Далее" вместо "Поиск"
                    
                    // Автоматически выбираем первый мост если он единственный
                    if bridges.count == 1 {
                        print("🎯 Автоматически выбираем единственный найденный мост")
                        self?.selectBridge(bridges[0])
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            // Сразу переходим к запросу разрешения локальной сети
            currentStep = .localNetworkPermission
        case .localNetworkPermission:
            currentStep = .searchBridges
        case .searchBridges:
            if !discoveredBridges.isEmpty {
                currentStep = .bridgeFound
            }
        case .bridgeFound:
            currentStep = .linkButton
        case .linkButton:
            currentStep = .connected
        case .connected:
            // Завершаем онбординг
            appViewModel.showSetup = false
        }
        
        // MARK: - QR Code Steps (закомментировано)
        /*
        case .cameraPermission:
            // После разрешения камеры сразу показываем сканер
            requestCameraPermission()
        case .qrScanner:
            currentStep = .localNetworkPermission
        */
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
            currentStep = .bridgeFound
        case .connected:
            currentStep = .linkButton
        }
        
        // MARK: - QR Code Steps (закомментировано)
        /*
        case .cameraPermission:
            currentStep = .welcome
        case .qrScanner:
            currentStep = .cameraPermission
        */
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
    
    // MARK: - Bridge Search
        
        func startBridgeSearch() {
            print("🔍 Начинаем поиск мостов в сети")
            isSearchingBridges = true
            discoveredBridges.removeAll()
            
            appViewModel.searchForBridges()
            
            // Таймаут поиска - исправлено для предотвращения сброса после успешного подключения
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self else { return }
                
                // ИСПРАВЛЕНИЕ: Проверяем не подключились ли мы уже к мосту
                // Если мост уже подключен, не сбрасываем состояние
                if self.appViewModel.connectionStatus == .connected ||
                   self.appViewModel.connectionStatus == .needsAuthentication {
                    print("✅ Мост уже найден и подключен, пропускаем таймаут")
                    return
                }
                
                self.isSearchingBridges = false
                
                // Проверяем результаты только если мост еще не подключен
                if let error = self.appViewModel.error as? HueAPIError,
                   case .localNetworkPermissionDenied = error {
                    print("🚫 Отказано в разрешении локальной сети")
                    self.showLocalNetworkAlert = true
                } else if self.discoveredBridges.isEmpty {
                    print("❌ Поиск завершен: мосты не найдены в локальной сети")
                    print("💡 Проверьте:")
                    print("   1. Мост подключен к той же Wi-Fi сети")
                    print("   2. Мост включен и работает")
                    print("   3. Разрешения локальной сети в настройках iOS")
                } else {
                    print("✅ Поиск завершен: найдено мостов: \(self.discoveredBridges.count)")
                    // Остаемся на экране поиска, но показываем кнопку "Далее" вместо "Поиск"
                    // Переход к bridgeFound будет только по нажатию кнопки
                }
            }
        }
    
    private func searchForSpecificBridge(bridgeId: String) {
        print("🔍 Ищем конкретный мост с ID: \(bridgeId)")
        isSearchingBridges = true
        
        appViewModel.discoverBridge(bySerial: bridgeId) { [weak self] bridge in
            DispatchQueue.main.async {
                self?.isSearchingBridges = false
                
                if let bridge = bridge {
                    print("✅ Мост найден: \(bridge.id) по адресу \(bridge.internalipaddress)")
                    self?.discoveredBridges = [bridge]
                    self?.selectedBridge = bridge
                    self?.currentStep = .bridgeFound
                } else {
                    print("❌ Мост с ID \(bridgeId) не найден")
                    // Пробуем общий поиск
                    self?.startBridgeSearch()
                }
            }
        }
    }
    
    // MARK: - Bridge Connection
    
    func selectBridge(_ bridge: Bridge) {
        print("📡 Выбран мост: \(bridge.id)")
        selectedBridge = bridge
        appViewModel.currentBridge = bridge
    }
    
    func startBridgeConnection() {
        guard let bridge = selectedBridge else { 
            print("❌ Не выбран мост для подключения")
            return 
        }
        
        print("🔗 Начинаем подключение к мосту: \(bridge.id) at \(bridge.internalipaddress)")
        currentStep = .linkButton
        showLinkButtonAlert = true
        
        // Сначала подключаемся к мосту
        appViewModel.connectToBridge(bridge)
        
        // Сразу начинаем попытки авторизации без таймера
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.startContinuousAuthentication()
        }
    }
    
    private func startContinuousAuthentication() {
        // Запускаем непрерывные попытки авторизации каждые 2 секунды
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            print("🔐 Попытка создания пользователя...")
            self?.attemptCreateUser()
        }
    }
    
    /// Попытка создать пользователя
        private func attemptCreateUser() {
            #if canImport(UIKit)
            let deviceName = UIDevice.current.name
            #else
            let deviceName = Host.current().localizedName ?? "Mac"
            #endif
            
            // Используем улучшенный метод с проверкой локальной сети
            appViewModel.createUserWithRetry(appName: "BulbsHUE", completion: { [weak self] success in
                if success {
                    print("✅ Пользователь успешно создан! Подключение установлено!")
                    self?.cancelLinkButton()
                    self?.currentStep = .connected
                    
                    // Мгновенно закрываем setup после успешного подключения
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.appViewModel.showSetup = false
                    }
                } else {
                    // Проверяем ошибку локальной сети
                    if let error = self?.appViewModel.error as? HueAPIError,
                       case .localNetworkPermissionDenied = error {
                        print("🚫 Нет доступа к локальной сети!")
                        self?.cancelLinkButton()
                        self?.showLocalNetworkAlert = true
                    }
                    // Иначе продолжаем попытки - кнопка Link может быть еще не нажата
                }
            })
        }
    
    func cancelLinkButton() {
        linkButtonTimer?.invalidate()
        linkButtonTimer = nil
        showLinkButtonAlert = false
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
}
extension OnboardingViewModel {
    
    /// Улучшенная попытка создания пользователя
    func attemptCreateUserImproved() {
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
            checker.checkLocalNetworkPermission { [weak self] hasPermission in
                if hasPermission {
                    print("✅ Разрешение локальной сети получено")
                    self?.proceedWithConnection(bridge: bridge)
                } else {
                    print("🚫 Нет разрешения локальной сети")
                    self?.showLocalNetworkAlert = true
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
