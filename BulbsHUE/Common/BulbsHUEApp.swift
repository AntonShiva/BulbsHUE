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
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            MasterView()
                .environmentObject(navigationManager)
                .environmentObject(appViewModel)
        }
    }
}
