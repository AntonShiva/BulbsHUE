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
        switch currentStep {
        case .welcome:
            currentStep = .localNetworkPermission
        case .localNetworkPermission:
            currentStep = .searchBridges
        case .searchBridges:
            if !discoveredBridges.isEmpty {
                currentStep = .linkButton
            }
        case .linkButton:
            break
        case .connected:
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
