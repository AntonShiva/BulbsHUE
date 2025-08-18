//
//  Conteiner.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct MainContainer: View {
    @EnvironmentObject var nav: NavigationManager
    
    var body: some View {
        Group {
            switch nav.currentRoute {
            case .environment: 
                EnvironmentView()
            case .schedule: 
                ScheduleView()
            case .music: 
                MusicView()
            case .addNewBulb:
                AddNewBulb()
            case .searchResults:
                // Этот экран больше не нужен как отдельный, так как состояние отслеживается в AddNewBulb
                AddNewBulb()
            case .selectCategories:
                // Этот экран также управляется состоянием в AddNewBulb
                AddNewBulb()
            case .menuView:
                // Показываем MenuView с выбранной лампой
                if let selectedLight = nav.selectedLightForMenu {
                    MenuView(
                        bulbName: selectedLight.metadata.name,
                        bulbIcon: getBulbIcon(for: selectedLight),
                        bulbType: getBulbType(for: selectedLight)
                    )
                } else {
                    // Fallback если лампа не выбрана
                    EnvironmentView()
                }
            case .development:
                DevelopmentMenuView()
            case .migrationDashboard:
                MigrationDashboardView()
            case .addRoom:
                AddNewRoom()
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    private func getBulbIcon(for light: Light) -> String {
        // Возвращаем иконку из пользовательских настроек или дефолтную
        return light.metadata.userSubtypeIcon ?? "f1"
    }
    
    private func getBulbType(for light: Light) -> String {
        // Возвращаем тип из пользовательских настроек или дефолтный
        return light.metadata.userSubtypeName ?? light.metadata.archetype ?? "Smart Light"
    }
}
