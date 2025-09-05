//
//  OnboardingViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 30.07.2025.

import SwiftUI
import AVFoundation
import Combine

@MainActor
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
    @Published var linkButtonPressed = false
    @Published var connectionError: String? = nil
    
    // MARK: - Internal Properties
    
    internal var appViewModel: AppViewModelProtocol
    internal var linkButtonTimer: Timer?
    internal var cancellables = Set<AnyCancellable>()
    internal var connectionAttempts = 0
    internal let maxConnectionAttempts = 30
    internal var lastLightRequestTime = Date.distantPast
    internal var lastGroupRequestTime = Date.distantPast
    internal let lightRequestInterval: TimeInterval = 0.1
    internal let groupRequestInterval: TimeInterval = 1.0
    
    // MARK: - Initialization
    
    init(appViewModel: AppViewModelProtocol) {
        self.appViewModel = appViewModel
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        appViewModel.connectionStatusPublisher
            .sink { [weak self] status in
                self?.handleConnectionStatusChange(status)
            }
            .store(in: &cancellables)
        
        appViewModel.discoveredBridgesPublisher
            .sink { [weak self] bridges in
                self?.handleDiscoveredBridges(bridges)
            }
            .store(in: &cancellables)
        
        appViewModel.errorPublisher
            .sink { [weak self] error in
                if let hueError = error as? HueAPIError {
                    self?.handleConnectionError(hueError)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Internal Helper Methods
    
    internal func handleConnectionStatusChange(_ status: ConnectionStatus) {
        switch status {
        case .connected:
            print("✅ OnboardingViewModel: Подключение успешно установлено!")
            handleSuccessfulConnection()
        case .discovered:
            if !discoveredBridges.isEmpty {
                print("📡 OnboardingViewModel: Мосты обнаружены")
            }
        case .needsAuthentication:
            print("🔐 OnboardingViewModel: Требуется авторизация (нажатие Link Button)")
        case .disconnected:
            print("❌ OnboardingViewModel: Отключено")
        case .searching:
            print("🔍 OnboardingViewModel: Поиск мостов...")
        @unknown default:
            break
        }
    }
    
    internal func handleDiscoveredBridges(_ bridges: [Bridge]) {
        let unique = bridges.reduce(into: [Bridge]()) { acc, item in
            var normalized = item
            normalized.id = item.normalizedId
            if !acc.contains(where: { $0.normalizedId == normalized.normalizedId ||
                                     $0.internalipaddress == normalized.internalipaddress }) {
                acc.append(normalized)
            }
        }
        discoveredBridges = unique
        
        if !bridges.isEmpty && currentStep == .searchBridges {
            print("✅ Получены мосты от AppViewModel: \(bridges.count), уникальных: \(unique.count)")
            if unique.count == 1, let only = unique.first {
                print("🎯 Автоматически выбираем единственный найденный мост")
                selectBridge(only)
            }
        }
    }
    
    internal func handleSuccessfulConnection() {
        print("🎉 Подключение успешно установлено!")
        linkButtonTimer?.invalidate()
        linkButtonTimer = nil
        isConnecting = false
        showLinkButtonAlert = false
        linkButtonPressed = true
        connectionError = nil
        currentStep = .connected
        
        Task { @MainActor in
            try await Task.sleep(for: .seconds(1))
            appViewModel.showSetup = false
        }
    }
    
    internal func handleConnectionError(_ error: HueAPIError) {
        switch error {
        case .linkButtonNotPressed:
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
}

enum OnboardingStep {
    case welcome
    case localNetworkPermission
    case searchBridges
    case linkButton
    case connected
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ OnboardingViewModel.swift
 
 Описание:
 Основной ViewModel для процесса онбординга приложения BulbsHUE.
 Управляет состоянием, свойствами и базовой логикой подключения.
 
 Основные компоненты:
 - Published свойства для UI binding
 - Internal свойства для внутренней логики
 - Обработчики изменения состояния подключения
 - Базовые helper методы
 
 Использование:
 let viewModel = OnboardingViewModel(appViewModel: appViewModel)
 
 Зависимости:
 - AppViewModel для управления подключением
 - SwiftUI, Combine для реактивности
 
 Связанные файлы:
 - OnboardingViewModel+Navigation.swift - навигация по шагам
 - OnboardingViewModel+Connection.swift - логика подключения
 - OnboardingViewModel+LinkButton.swift - обработка Link Button
 - OnboardingViewModel+Bridge.swift - работа с мостами
 - OnboardingViewModel+Permissions.swift - обработка разрешений
 */
