//
//  OnboardingViewModel+PermissionCheck.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import SwiftUI

extension OnboardingViewModel {
    
    // MARK: - Permission Check Connection
    
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
            proceedWithConnection(bridge: bridge)
        }
    }
    
    private func proceedWithConnection(bridge: Bridge) {
        print("🔗 Начинаем подключение к мосту: \(bridge.id) at \(bridge.internalipaddress)")
        currentStep = .linkButton
        showLinkButtonAlert = true
        
        appViewModel.connectToBridge(bridge)
        
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.attemptCreateUserImproved()
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ OnboardingViewModel+PermissionCheck.swift
 
 Описание:
 Расширение для подключения с предварительной проверкой разрешений.
 
 Основные методы:
 - startBridgeConnectionWithPermissionCheck() - подключение с проверкой разрешений
 - proceedWithConnection() - продолжение подключения после проверки
 
 Использование:
 viewModel.startBridgeConnectionWithPermissionCheck()
 
 Зависимости:
 - LocalNetworkPermissionChecker для проверки разрешений
 - iOS 14.0+ для async/await
 */
