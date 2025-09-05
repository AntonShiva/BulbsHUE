//
//  OnboardingViewModel+LinkButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import SwiftUI
import Combine

extension OnboardingViewModel {
    
    // MARK: - Link Button Enhanced
    
    func startBridgeConnectionFixed() {
        guard let bridge = selectedBridge else {
            print("❌ Не выбран мост для подключения")
            connectionError = "Не выбран мост для подключения"
            return
        }
        
        guard !isConnecting else {
            print("⚠️ Подключение уже в процессе")
            return
        }
        
        print("🔗 Начинаем ИСПРАВЛЕННОЕ подключение к мосту: \(bridge.id)")
        
        isConnecting = true
        connectionAttempts = 0
        linkButtonPressed = false
        connectionError = nil
        linkButtonCountdown = 60
        
        appViewModel.connectToBridge(bridge)
        
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
    
    private func handleLinkButtonState(_ state: LinkButtonState) {
        Task { @MainActor in
            switch state {
            case .idle:
                print("🔄 Link Button: Готов к подключению")
                self.isConnecting = false
                self.connectionAttempts = 0
                
            case .waiting(let attempt, let maxAttempts):
                print("⏳ Link Button: Ожидание нажатия (попытка \(attempt)/\(maxAttempts))")
                self.isConnecting = true
                self.connectionAttempts = attempt
                self.linkButtonCountdown = Swift.max(0, (maxAttempts - attempt) * 2)
                
                if !self.showLinkButtonAlert {
                    self.showLinkButtonAlert = true
                }
                
            case .success:
                print("✅ Link Button: УСПЕШНОЕ ПОДКЛЮЧЕНИЕ!")
                self.isConnecting = false
                self.linkButtonPressed = true
                self.showLinkButtonAlert = false
                self.connectionError = nil
                self.currentStep = .connected
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
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
    
    private func handleConnectionResult(_ result: Result<String, Error>) {
        Task { @MainActor in
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
    
    func cancelLinkButtonFixed() {
        print("🚫 Отмена процесса Link Button")
        
        isConnecting = false
        linkButtonPressed = false
        connectionAttempts = 0
        linkButtonCountdown = 60
        connectionError = nil
        showLinkButtonAlert = false
    }
    
    func attemptCreateUserImproved() {
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
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    self?.appViewModel.showSetup = false
                }
            }
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ OnboardingViewModel+LinkButton.swift
 
 Описание:
 Расширение для улучшенной обработки Link Button с состояниями.
 
 Основные методы:
 - startBridgeConnectionFixed() - улучшенное подключение с обработкой состояний
 - handleLinkButtonState() - обработка состояний Link Button
 - handleConnectionResult() - обработка результата подключения
 - attemptCreateUserImproved() - улучшенная попытка создания пользователя
 
 Использование:
 viewModel.startBridgeConnectionFixed()
 
 Зависимости:
 - LinkButtonState enum для состояний
 - LinkButtonError для ошибок
 - AppViewModel для API вызовов
 */
