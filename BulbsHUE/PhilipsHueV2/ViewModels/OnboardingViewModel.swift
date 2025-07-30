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
    @Published var showQRScanner = false
    @Published var showCameraPermissionAlert = false
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
                    self?.currentStep = .bridgeFound
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .cameraPermission
        case .cameraPermission:
            // После разрешения камеры сразу показываем сканер
            requestCameraPermission()
        case .qrScanner:
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
    }
    
    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .cameraPermission:
            currentStep = .welcome
        case .qrScanner:
            currentStep = .cameraPermission
        case .localNetworkPermission:
            currentStep = .qrScanner
        case .searchBridges:
            currentStep = .localNetworkPermission
        case .bridgeFound:
            currentStep = .searchBridges
        case .linkButton:
            currentStep = .bridgeFound
        case .connected:
            currentStep = .linkButton
        }
    }
    
    // MARK: - Camera Permission
    
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
    
    // MARK: - QR Code Handling
    
    func handleScannedQR(_ code: String) {
        print("📱 OnboardingViewModel: Получен QR-код: '\(code)'")
        showQRScanner = false
        
        let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ⚠️ Опционально — проверка, что это HomeKit QR
        if cleanedCode.hasPrefix("X-HM://") {
            print("✅ Распознан HomeKit QR-код")
            
            // Пробуем, вдруг получится вытащить bridgeId (например, если это кастомный код)
            if let bridgeId = parseBridgeId(from: code) {
                print("✅ Bridge ID успешно извлечен: \(bridgeId)")
                searchForSpecificBridge(bridgeId: bridgeId)
            } else {
                print("⚠️ Не удалось извлечь Bridge ID, но продолжаем")
                // Выполняем обычный поиск всех мостов
                startBridgeSearch()
            }

            // Переход к следующему шагу в любом случае
            currentStep = .searchBridges

        } else {
            print("❌ Неверный формат QR-кода")
            // Показать алерт или сбросить
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
    
    // MARK: - Bridge Search
    
    func startBridgeSearch() {
        print("🔍 Начинаем поиск мостов в сети")
        isSearchingBridges = true
        appViewModel.searchForBridges()
        
        // Таймаут поиска
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.isSearchingBridges = false
            if self?.discoveredBridges.isEmpty ?? true {
                print("❌ Мосты не найдены")
                // Можно показать алерт
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
        guard let bridge = selectedBridge else { return }
        
        print("🔗 Начинаем подключение к мосту: \(bridge.id)")
        currentStep = .linkButton
        showLinkButtonAlert = true
        linkButtonCountdown = 30
        
        // Подключаемся к мосту
        appViewModel.connectToBridge(bridge)
        
        // Запускаем таймер для попыток авторизации
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.linkButtonCountdown -= 1
            
            if self?.linkButtonCountdown ?? 0 % 3 == 0 {
                print("🔐 Попытка создания пользователя (осталось: \(self?.linkButtonCountdown ?? 0) сек)")
                self?.attemptCreateUser()
            }
            
            if self?.linkButtonCountdown ?? 0 <= 0 {
                print("⏰ Время истекло")
                self?.cancelLinkButton()
            }
        }
    }
    
    private func attemptCreateUser() {
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        
        appViewModel.createUser(appName: "BulbsHUE", completion: { [weak self] success in
            if success {
                print("✅ Пользователь успешно создан!")
                self?.cancelLinkButton()
                self?.currentStep = .connected
                
                // Даем время на анимацию перед закрытием
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.appViewModel.showSetup = false
                }
            } else {
                print("⏳ Кнопка Link еще не нажата, продолжаем попытки...")
            }
        })
    }
    
    func cancelLinkButton() {
        linkButtonTimer?.invalidate()
        linkButtonTimer = nil
        showLinkButtonAlert = false
        linkButtonCountdown = 30
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

// MARK: - OnboardingStep

enum OnboardingStep {
    case welcome
    case cameraPermission
    case qrScanner
    case localNetworkPermission
    case searchBridges
    case bridgeFound
    case linkButton
    case connected
}
