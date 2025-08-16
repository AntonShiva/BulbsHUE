//
//  OnboardingViewModel+Permissions.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import SwiftUI
import UIKit

extension OnboardingViewModel {
    
    // MARK: - Permissions
    
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
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func showLocalNetworkInfo() {
        showLocalNetworkAlert = true
    }
    
    func showGenericErrorAlert(_ message: String? = nil) {
        connectionError = message ?? "Произошла ошибка. Попробуйте ещё раз."
        showLinkButtonAlert = false
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ OnboardingViewModel+Permissions.swift
 
 Описание:
 Расширение для работы с системными разрешениями iOS.
 
 Основные методы:
 - requestLocalNetworkPermissionOnWelcome() - запрос разрешения локальной сети
 - openAppSettings() - открытие настроек приложения
 - showLocalNetworkInfo() - показ информации о локальной сети
 - showGenericErrorAlert() - показ общей ошибки
 
 Использование:
 viewModel.requestLocalNetworkPermissionOnWelcome()
 
 Зависимости:
 - LocalNetworkPermissionChecker для проверки разрешений
 - UIApplication для системных вызовов
 */
