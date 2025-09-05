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
    @State private var navigationManager = NavigationManager.shared
    
    /// Сервис для персистентного хранения данных
    @State private var dataPersistenceService = DataPersistenceService()
    
    /// Основной ViewModel приложения
    @State private var appViewModel: AppViewModel
    
    // MARK: - Initialization
    
    init() {
        let dataService = DataPersistenceService()
        self._dataPersistenceService = State(initialValue: dataService)
        
        let appVM = AppViewModel(dataPersistenceService: dataService)
        self._appViewModel = State(initialValue: appVM)
        
        // ✅ Устанавливаем обратную связь для обновления ламп
        dataService.appViewModel = appVM
        
        // ✅ НАСТРОЙКА РЕАЛЬНЫХ REPOSITORIES
        // Конфигурируем DIContainer с реальными зависимостями
        DIContainer.shared.configureLightRepository(
            appViewModel: appVM,
            dataPersistenceService: dataService
        )
        
        // ✅ НАСТРОЙКА РЕАЛЬНОГО ROOM REPOSITORY
        // Конфигурируем RoomRepository для сохранения комнат в SwiftData
        DIContainer.shared.configureRoomRepository(
            dataPersistenceService: dataService
        )
        
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            MasterView()
                .environment(appViewModel)
                .environment(NavigationManager.shared)
                .environment(dataPersistenceService)
                .modelContainer(dataPersistenceService.container)
                .onAppear {
                    NavigationManager.shared.dataPersistenceService = dataPersistenceService
                }
        }
    }
}
