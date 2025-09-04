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
        
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            
            if appViewModel.connectionStatus == .connected ||
               appViewModel.connectionStatus == .needsAuthentication {
                print("✅ Мост уже найден и подключен")
                return
            }
            
            isSearchingBridges = false
            
            if let error = appViewModel.error as? HueAPIError,
               case .localNetworkPermissionDenied = error {
                print("🚫 Отказано в разрешении локальной сети")
                showLocalNetworkAlert = true
            } else if discoveredBridges.isEmpty {
                print("❌ Мосты не найдены")
                connectionError = "Мосты не найдены в локальной сети. Проверьте подключение."
            } else {
                print("✅ Найдено мостов: \(discoveredBridges.count)")
            }
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
