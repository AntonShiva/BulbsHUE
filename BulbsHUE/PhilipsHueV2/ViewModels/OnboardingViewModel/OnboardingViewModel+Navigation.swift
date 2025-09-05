//
//  OnboardingViewModel+Navigation.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import SwiftUI

extension OnboardingViewModel {
    
    // MARK: - Navigation
    
    func nextStep() {
        print("🚀 OnboardingViewModel.nextStep() - текущий шаг: \(currentStep)")
        
        switch currentStep {
        case .welcome:
            currentStep = .localNetworkPermission
            print("✅ Переход к .localNetworkPermission")
        case .localNetworkPermission:
            currentStep = .searchBridges
            print("✅ Переход к .searchBridges")
        case .searchBridges:
            if !discoveredBridges.isEmpty {
                currentStep = .linkButton
                print("✅ Переход к .linkButton")
            } else {
                print("⚠️ Не найдены мосты для перехода к .linkButton")
            }
        case .linkButton:
            print("⚠️ Неожиданный вызов nextStep() из .linkButton")
            break
        case .connected:
            print("🎯 ЗАВЕРШЕНИЕ ОНБОРДИНГА: Устанавливаем appViewModel.showSetup = false")
            print("🔍 AppViewModel до изменения - showSetup: \(appViewModel.showSetup)")
            appViewModel.showSetup = false
            print("✅ AppViewModel после изменения - showSetup: \(appViewModel.showSetup)")
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
        case .linkButton:
            cancelLinkButton()
            currentStep = .searchBridges
        case .connected:
            currentStep = .linkButton
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ OnboardingViewModel+Navigation.swift
 
 Описание:
 Расширение для управления навигацией между шагами онбординга.
 
 Основные методы:
 - nextStep() - переход к следующему шагу
 - previousStep() - возврат к предыдущему шагу
 
 Использование:
 viewModel.nextStep()
 viewModel.previousStep()
 
 Зависимости:
 - OnboardingViewModel основной класс
 - OnboardingStep enum
 */
