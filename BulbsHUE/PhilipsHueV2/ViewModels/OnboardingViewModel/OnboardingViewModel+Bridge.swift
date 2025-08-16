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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            
            if self.appViewModel.connectionStatus == .connected ||
               self.appViewModel.connectionStatus == .needsAuthentication {
                print("✅ Мост уже найден и подключен")
                return
            }
            
            self.isSearchingBridges = false
            
            if let error = self.appViewModel.error as? HueAPIError,
               case .localNetworkPermissionDenied = error {
                print("🚫 Отказано в разрешении локальной сети")
                self.showLocalNetworkAlert = true
            } else if self.discoveredBridges.isEmpty {
                print("❌ Мосты не найдены")
                self.connectionError = "Мосты не найдены в локальной сети. Проверьте подключение."
            } else {
                print("✅ Найдено мостов: \(self.discoveredBridges.count)")
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
