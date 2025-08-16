//
//  OnboardingViewModel+UI.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import SwiftUI

extension OnboardingViewModel {
    
    // MARK: - UI Helpers
    
    var linkButtonStatusText: String {
        if linkButtonPressed {
            return "✅ Подключение установлено!"
        } else if isConnecting {
            if connectionAttempts > 0 {
                return "Попытка \(connectionAttempts) из 30..."
            } else {
                return "Ожидание нажатия кнопки Link..."
            }
        } else if let error = connectionError {
            return error
        } else {
            return "Готов к подключению"
        }
    }
    
    var linkButtonStatusColor: Color {
        if linkButtonPressed {
            return .green
        } else if connectionError != nil {
            return .red
        } else if isConnecting {
            return .cyan
        } else {
            return .gray
        }
    }
    
    var canProceedFromLinkButton: Bool {
        return linkButtonPressed && !isConnecting
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ OnboardingViewModel+UI.swift
 
 Описание:
 Расширение с вычисляемыми свойствами для UI.
 
 Основные свойства:
 - linkButtonStatusText - текст статуса для отображения
 - linkButtonStatusColor - цвет индикатора статуса
 - canProceedFromLinkButton - проверка готовности к переходу
 
 Использование:
 Text(viewModel.linkButtonStatusText)
 .foregroundColor(viewModel.linkButtonStatusColor)
 
 Зависимости:
 - SwiftUI для Color типа
 */
