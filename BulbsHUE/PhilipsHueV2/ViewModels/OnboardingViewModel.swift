//
//  OnboardingViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 30.07.2025.
//

import Foundation
import SwiftUI
import AVFoundation

/// ViewModel для управления процессом онбординга
@MainActor
class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Текущий шаг онбординга
    @Published var currentStep: OnboardingStep = .welcome
    
    /// Показать алерт разрешения камеры
    @Published var showCameraPermissionAlert = false
    
    /// Показать алерт локальной сети
    @Published var showLocalNetworkAlert = false
    
    /// Показать сканер QR-кода
    @Published var showQRScanner = false
    
    /// Статус поиска мостов
    @Published var isSearchingBridges = false
    
    /// Найденные мосты
    @Published var discoveredBridges: [Bridge] = []
    
    /// Выбранный мост для подключения
    @Published var selectedBridge: Bridge?
    
    /// Показать алерт нажатия кнопки на мосту
    @Published var showLinkButtonAlert = false
    
    /// Счетчик времени для нажатия кнопки Link
    @Published var linkButtonCountdown = 30
    
    /// Таймер для обратного отсчета
    private var linkButtonTimer: Timer?
    
    /// Ссылка на главный ViewModel
    private let appViewModel: AppViewModel
    
    // MARK: - Initialization
    
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }
    
    // MARK: - Onboarding Steps Management
    
    /// Переход к следующему шагу
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .cameraPermission
        case .cameraPermission:
            showQRScanner = true
            currentStep = .qrScanner
        case .qrScanner:
            currentStep = .localNetworkPermission
        case .localNetworkPermission:
            currentStep = .searchBridges
        case .searchBridges:
            currentStep = .bridgeFound
        case .bridgeFound:
            currentStep = .linkButton
        case .linkButton:
            currentStep = .connected
        case .connected:
            // Завершение онбординга
            completeOnboarding()
        }
    }
    
    /// Возврат к предыдущему шагу
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
    
    // MARK: - Permission Methods
    
    /// Проверка и запрос разрешения камеры
    func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Разрешение уже получено, переходим к сканеру
            nextStep()
            
        case .notDetermined:
            // Запрашиваем разрешение
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.nextStep()
                    } else {
                        self?.showCameraPermissionAlert = true
                    }
                }
            }
            
        case .denied, .restricted:
            // Показываем алерт с предложением открыть настройки
            showCameraPermissionAlert = true
            
        @unknown default:
            showCameraPermissionAlert = true
        }
    }
    
    /// Открытие настроек приложения
    func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    /// Показать информацию о локальной сети
    func showLocalNetworkInfo() {
        showLocalNetworkAlert = true
    }
    
    // MARK: - Bridge Discovery Methods
    
    /// Начать поиск мостов
    func startBridgeSearch() {
        isSearchingBridges = true
        discoveredBridges = []
        
        // Запускаем поиск через AppViewModel
        appViewModel.searchForBridges()
        
        // Подписываемся на обновления найденных мостов
        // Симулируем поиск для демонстрации
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isSearchingBridges = false
            
            // Проверяем найденные мосты из AppViewModel
            if !self?.appViewModel.discoveredBridges.isEmpty ?? true {
                self?.discoveredBridges = self?.appViewModel.discoveredBridges ?? []
                self?.nextStep() // Переходим к экрану найденного моста
            }
        }
    }
    
    /// Выбор моста для подключения
    func selectBridge(_ bridge: Bridge) {
        selectedBridge = bridge
        nextStep() // Переходим к экрану нажатия кнопки Link
    }
    
    // MARK: - Bridge Connection Methods
    
    /// Начать процесс подключения к мосту
    func startBridgeConnection() {
        guard let bridge = selectedBridge else { return }
        
        // Подключаемся к мосту через AppViewModel
        appViewModel.connectToBridge(bridge)
        
        // Показываем алерт нажатия кнопки
        showLinkButtonAlert = true
        linkButtonCountdown = 30
        
        // Запускаем таймер
        startLinkButtonTimer()
    }
    
    /// Запуск таймера для кнопки Link
    private func startLinkButtonTimer() {
        linkButtonTimer?.invalidate()
        
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.linkButtonCountdown -= 1
            
            // Пробуем создать пользователя каждые 3 секунды
            if self.linkButtonCountdown % 3 == 0 {
                self.attemptCreateUser()
            }
            
            // Проверяем таймаут
            if self.linkButtonCountdown <= 0 {
                self.cancelLinkButton()
            }
        }
    }
    
    /// Попытка создать пользователя на мосту
    private func attemptCreateUser() {
        guard let bridge = selectedBridge else { return }
        
        appViewModel.createUser(on: bridge, appName: "BulbsHUE", deviceName: "iOS Device") { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // Успешное подключение
                    self?.linkButtonTimer?.invalidate()
                    self?.showLinkButtonAlert = false
                    self?.nextStep() // Переходим к экрану успешного подключения
                }
            }
        }
    }
    
    /// Отмена процесса подключения
    func cancelLinkButton() {
        linkButtonTimer?.invalidate()
        showLinkButtonAlert = false
        // Возвращаемся к предыдущему шагу
        previousStep()
    }
    
    // MARK: - QR Code Handling
    
    /// Обработка отсканированного QR-кода
    func handleScannedQR(_ code: String) {
        showQRScanner = false
        
        // Парсим QR-код (формат: bridge-id: ECB5FAFFE896811 + номер)
        if let bridgeId = parseBridgeId(from: code) {
            // Ищем мост с данным ID
            searchForSpecificBridge(bridgeId: bridgeId)
        }
    }
    
    /// Парсинг ID моста из QR-кода
    private func parseBridgeId(from code: String) -> String? {
        // Обрабатываем различные форматы QR-кода
        if code.contains("bridge-id:") {
            // Формат: bridge-id: ECB5FAFFE896811
            let components = code.components(separatedBy: "bridge-id:")
            if components.count > 1 {
                return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if code.hasPrefix("S#") {
            // Формат: S#12345678
            return String(code.dropFirst(2))
        }
        
        return nil
    }
    
    /// Поиск конкретного моста по ID
    private func searchForSpecificBridge(bridgeId: String) {
        isSearchingBridges = true
        
        // Запускаем поиск мостов
        appViewModel.searchForBridges()
        
        // Ждем результат и ищем наш мост
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isSearchingBridges = false
            
            // Ищем мост с нужным ID
            if let foundBridge = self?.appViewModel.discoveredBridges.first(where: { bridge in
                bridge.id.contains(bridgeId) || bridge.serialNumber?.contains(bridgeId) == true
            }) {
                self?.discoveredBridges = [foundBridge]
                self?.selectedBridge = foundBridge
                self?.currentStep = .bridgeFound
            } else {
                // Мост не найден, продолжаем общий поиск
                self?.startBridgeSearch()
            }
        }
    }
    
    // MARK: - Completion
    
    /// Завершение онбординга
    private func completeOnboarding() {
        // Скрываем экран настройки в AppViewModel
        appViewModel.showSetup = false
    }
}

// MARK: - Onboarding Steps

/// Шаги онбординга
enum OnboardingStep: CaseIterable {
    case welcome
    case cameraPermission
    case qrScanner
    case localNetworkPermission
    case searchBridges
    case bridgeFound
    case linkButton
    case connected
    
    var title: String {
        switch self {
        case .welcome:
            return "Добро пожаловать!"
        case .cameraPermission:
            return "Разрешение камеры"
        case .qrScanner:
            return "Сканирование QR-кода"
        case .localNetworkPermission:
            return "Доступ к локальной сети"
        case .searchBridges:
            return "Поиск Hue Bridge"
        case .bridgeFound:
            return "Найден блок управления Hue"
        case .linkButton:
            return "Подключение к мосту"
        case .connected:
            return "Подключен блок управления Hue"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Хотите добавить Hue Bridge?"
        case .cameraPermission:
            return "Приложение будет использовать вашу камеру для сканирования QR-кодов"
        case .qrScanner:
            return "Отсканируйте QR-код на вашем Hue Bridge"
        case .localNetworkPermission:
            return "Для работы с Hue Bridge необходим доступ к локальной сети"
        case .searchBridges:
            return "Поиск доступных Hue Bridge в сети"
        case .bridgeFound:
            return "Нажмите кнопку в верхней части устройства Hue Bridge, которое хотите подключить"
        case .linkButton:
            return "Нажмите круглую кнопку Link на вашем Hue Bridge"
        case .connected:
            return "Ваш Hue Bridge успешно подключен к приложению"
        }
    }
}