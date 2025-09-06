//
//  OnboardingViewModel+Bridge.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import SwiftUI

extension OnboardingViewModel {
    
    // MARK: - Bridge Management
    
    func selectBridge(_ bridge: Bridge) {
        print("📡 Выбран мост: \(bridge.id)")
        selectedBridge = bridge
        appViewModel.currentBridge = bridge
    }
    
    func startBridgeSearch() {
        print("🔍 Начинаем поиск мостов в сети")
        isSearchingBridges = true
        discoveredBridges.removeAll()
        connectionError = nil
        
        appViewModel.searchForBridges()
        
        // ✅ ИСПРАВЛЕНИЕ: Отслеживаем изменения состояния вместо фиксированного таймаута
        let startTime = Date()
        let maxSearchTime: TimeInterval = 30.0 // Максимальное время поиска
        
        func checkSearchProgress() {
            // Обновляем состояние из AppViewModel
            updateFromAppViewModel()
            
            // Проверяем различные условия завершения
            if appViewModel.connectionStatus == .connected ||
               appViewModel.connectionStatus == .needsAuthentication {
                print("✅ Мост уже найден и подключен")
                isSearchingBridges = false
                return
            }
            
            if appViewModel.connectionStatus == .discovered && !appViewModel.discoveredBridges.isEmpty {
                print("✅ Найдено мостов: \(appViewModel.discoveredBridges.count)")
                isSearchingBridges = false
                updateFromAppViewModel()
                return
            }
            
            // Проверяем ошибки
            if let error = appViewModel.error as? HueAPIError,
               case .localNetworkPermissionDenied = error {
                print("🚫 Отказано в разрешении локальной сети")
                isSearchingBridges = false
                showLocalNetworkAlert = true
                return
            }
            
            // Проверяем таймаут
            if Date().timeIntervalSince(startTime) > maxSearchTime {
                print("⏰ Превышено максимальное время поиска")
                isSearchingBridges = false
                if appViewModel.discoveredBridges.isEmpty {
                    connectionError = "Мосты не найдены в локальной сети. Проверьте подключение."
                } else {
                    updateFromAppViewModel()
                }
                return
            }
            
            // Если поиск еще продолжается - планируем следующую проверку
            if appViewModel.connectionStatus == .searching && isSearchingBridges {
                Task { @MainActor in
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
                    checkSearchProgress()
                }
            } else {
                // Поиск завершен по другим причинам
                isSearchingBridges = false
                updateFromAppViewModel()
            }
        }
        
        // Запускаем первую проверку через короткую задержку
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            checkSearchProgress()
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ OnboardingViewModel+Bridge.swift
 
 Описание:
 Расширение для работы с Hue Bridge - поиск и выбор.
 
 Основные методы:
 - selectBridge() - выбор моста для подключения
 - startBridgeSearch() - запуск поиска мостов в сети
 
 Использование:
 viewModel.startBridgeSearch()
 viewModel.selectBridge(bridge)
 
 Зависимости:
 - AppViewModel для API поиска
 - Bridge модель данных
 */
