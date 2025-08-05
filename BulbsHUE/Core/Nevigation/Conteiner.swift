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
            }
        }
        .transition(.opacity)
    }
}
