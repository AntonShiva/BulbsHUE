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
    
    /// Основной ViewModel приложения
    @StateObject private var appViewModel = AppViewModel()
    
    /// Сервис для персистентного хранения данных
    @StateObject private var dataPersistenceService = DataPersistenceService()
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            MasterView()
                .environmentObject(appViewModel)
                .environmentObject(NavigationManager.shared)
                .environmentObject(dataPersistenceService)
                .modelContainer(dataPersistenceService.container)
                .onAppear {
                    NavigationManager.shared.dataPersistenceService = dataPersistenceService
                }
        }
    }
}
