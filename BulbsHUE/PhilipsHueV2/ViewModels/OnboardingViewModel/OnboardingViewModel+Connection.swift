//
//  OnboardingViewModel+Connection.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import SwiftUI
import Combine

extension OnboardingViewModel {
    
    // MARK: - Connection Management
    
    func startBridgeConnection() {
        guard let bridge = selectedBridge else {
            print("❌ Не выбран мост для подключения")
            return
        }
        
        guard !isConnecting else {
            print("⚠️ Подключение уже в процессе")
            return
        }
        
        print("🔗 Начинаем подключение к мосту: \(bridge.id) at \(bridge.internalipaddress)")
        isConnecting = true
        connectionAttempts = 0
        linkButtonPressed = false
        connectionError = nil
        
        appViewModel.connectToBridge(bridge)
        showLinkButtonAlert = true
        startLinkButtonPolling()
    }
    
    func startLinkButtonPolling() {
        print("⏱ Запускаем опрос Link Button каждые 2 секунды")
        
        linkButtonTimer?.invalidate()
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.attemptCreateUser()
        }
        attemptCreateUser()
    }
    
    func attemptCreateUser() {
        connectionAttempts += 1
        
        print("🔐 Попытка #\(connectionAttempts) создания пользователя...")
        
        if connectionAttempts >= maxConnectionAttempts {
            print("⏰ Превышен лимит попыток подключения")
            handleConnectionTimeout()
            return
        }
        
        linkButtonCountdown = max(0, 60 - (connectionAttempts * 2))
        
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
                if let error = self.appViewModel.error as? HueAPIError {
                    switch error {
                    case .linkButtonNotPressed:
                        print("⏳ Link Button еще не нажат, продолжаем ожидание...")
                    case .localNetworkPermissionDenied:
                        print("🚫 Нет доступа к локальной сети!")
                        self.handleNetworkPermissionError()
                    default:
                        print("❌ Ошибка при создании пользователя: \(error)")
                    }
                }
            }
        }
    }
    
    func handleConnectionTimeout() {
        print("⏰ Время ожидания истекло")
        cancelLinkButton()
        connectionError = "Время ожидания истекло. Убедитесь, что вы нажали круглую кнопку Link на Hue Bridge и попробуйте снова."
        showLinkButtonAlert = false
    }
    
    func handleNetworkPermissionError() {
        cancelLinkButton()
        showLocalNetworkAlert = true
    }
    
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
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ OnboardingViewModel+Connection.swift
 
 Описание:
 Расширение для управления процессом подключения к Hue Bridge.
 
 Основные методы:
 - startBridgeConnection() - запуск подключения
 - startLinkButtonPolling() - опрос состояния Link Button
 - attemptCreateUser() - попытка создания пользователя
 - cancelLinkButton() - отмена процесса
 
 Использование:
 viewModel.startBridgeConnection()
 
 Зависимости:
 - AppViewModel для API вызовов
 - Timer для периодического опроса
 */
