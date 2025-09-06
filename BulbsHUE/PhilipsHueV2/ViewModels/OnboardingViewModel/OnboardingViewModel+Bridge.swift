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
        
        // ✅ ИСПРАВЛЕНИЕ: Заменяем рекурсию на async последовательность
        startSearchProgressMonitoring()
    }
    
    // ✅ ИСПРАВЛЕНИЕ: Безопасный мониторинг без рекурсии с proper cancellation
    @MainActor
    private func startSearchProgressMonitoring() {
        // Отменяем предыдущий поиск если есть
        searchMonitoringTask?.cancel()
        
        let startTime = Date()
        let maxSearchTime: TimeInterval = 30.0
        let checkInterval: TimeInterval = 0.5
        
        searchMonitoringTask = Task { [weak self] in
            guard let self = self else { return }
            
            while self.isSearchingBridges && !Task.isCancelled {
                await MainActor.run {
                    // Обновляем состояние из AppViewModel
                    self.updateFromAppViewModel()
                }
                
                // Проверяем условия завершения
                if await self.shouldStopSearching(startTime: startTime, maxSearchTime: maxSearchTime) {
                    break
                }
                
                // Ждем интервал проверки
                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
            
            // Очищаем ссылку на завершенный Task
            await MainActor.run {
                self.searchMonitoringTask = nil
            }
        }
    }
    
    // ✅ ИСПРАВЛЕНИЕ: Метод для отмены поиска
    @MainActor
    func stopBridgeSearch() {
        isSearchingBridges = false
        searchMonitoringTask?.cancel()
        searchMonitoringTask = nil
        print("🛑 Поиск мостов остановлен")
    }
    
    @MainActor
    private func shouldStopSearching(startTime: Date, maxSearchTime: TimeInterval) -> Bool {
        // Проверяем успешное подключение
        if appViewModel.connectionStatus == .connected ||
           appViewModel.connectionStatus == .needsAuthentication {
            print("✅ Мост уже найден и подключен")
            isSearchingBridges = false
            return true
        }
        
        // Проверяем найденные мосты
        if appViewModel.connectionStatus == .discovered && !appViewModel.discoveredBridges.isEmpty {
            print("✅ Найдено мостов: \(appViewModel.discoveredBridges.count)")
            isSearchingBridges = false
            updateFromAppViewModel()
            return true
        }
        
        // Проверяем ошибки
        if let error = appViewModel.error as? HueAPIError,
           case .localNetworkPermissionDenied = error {
            print("🚫 Отказано в разрешении локальной сети")
            isSearchingBridges = false
            showLocalNetworkAlert = true
            return true
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
            return true
        }
        
        // Проверяем изменение состояния поиска
        if appViewModel.connectionStatus != .searching {
            isSearchingBridges = false
            updateFromAppViewModel()
            return true
        }
        
        return false
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
