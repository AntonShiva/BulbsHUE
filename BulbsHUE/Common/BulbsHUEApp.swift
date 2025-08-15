//
//  BulbsHUEApp.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI
import SwiftData

@main
struct BulbsHUEApp: App {
    // MARK: - StateObjects
    
    /// Менеджер навигации приложения
    @StateObject private var navigationManager = NavigationManager.shared
    
    /// Сервис для персистентного хранения данных
    @StateObject private var dataPersistenceService = DataPersistenceService()
    
    /// Основной ViewModel приложения
    @StateObject private var appViewModel: AppViewModel
    
    /// Redux Store для новой архитектуры
    @StateObject private var store = AppStore()
    
    /// Адаптер для безопасной миграции
    @StateObject private var migrationAdapter: MigrationAdapter
    
    // MARK: - Initialization
    
    init() {
        let dataService = DataPersistenceService()
        self._dataPersistenceService = StateObject(wrappedValue: dataService)
        
        let appVM = AppViewModel(dataPersistenceService: dataService)
        self._appViewModel = StateObject(wrappedValue: appVM)
        
        let appStore = AppStore()
        self._store = StateObject(wrappedValue: appStore)
        self._migrationAdapter = StateObject(wrappedValue: MigrationAdapter(store: appStore, appViewModel: appVM))
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            MasterView()
                .environmentObject(appViewModel)
                .environmentObject(NavigationManager.shared)
                .environmentObject(dataPersistenceService)
                .environmentObject(store)
                .environmentObject(migrationAdapter)
                .modelContainer(dataPersistenceService.container)
                .onAppear {
                    NavigationManager.shared.dataPersistenceService = dataPersistenceService
                    
                    // Логирование статуса миграции при запуске
                    if MigrationFeatureFlags.debugMigration {
                        print("🚀 BulbsHUE запущен с миграцией")
                        print("   Redux Store инициализирован: ✅")
                        print("   MigrationAdapter готов: ✅")
                    }
                }
        }
    }
}
