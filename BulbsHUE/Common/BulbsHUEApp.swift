//
//  BulbsHUEApp.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI

@main
struct BulbsHUEApp: App {
    // MARK: - StateObjects
    
    /// Менеджер навигации приложения
    @StateObject private var navigationManager = NavigationManager.shared
    
    /// Основной ViewModel приложения
    @StateObject private var appViewModel = AppViewModel()
    
    /// Сервис для управления лампами - реализация протоколов
    @StateObject private var lightControlService: LightControlService
    
    /// ViewModel для управления отдельными лампами
    @StateObject private var itemControlViewModel: ItemControlViewModel
    
    // MARK: - Initialization
    
    init() {
        // Создаём сервис с внедрением зависимости
        let appVM = AppViewModel()
        let lightService = LightControlService(appViewModel: appVM)
        let itemVM = ItemControlViewModel(lightControlService: lightService)
        
        // Инициализируем StateObjects
        _appViewModel = StateObject(wrappedValue: appVM)
        _lightControlService = StateObject(wrappedValue: lightService)
        _itemControlViewModel = StateObject(wrappedValue: itemVM)
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            MasterView()
                .environmentObject(navigationManager)
                .environmentObject(appViewModel)
                .environmentObject(itemControlViewModel)
        }
    }
}
