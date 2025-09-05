//
//  ContentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI

struct MasterView: View {
    /// ✅ ОБНОВЛЕНО: @EnvironmentObject -> @Environment для @Observable
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(NavigationManager.self) private var navigationManager
    var body: some View {
        ZStack(alignment: .bottom) {
            BG()
            
            if appViewModel.showSetup {
                // Показываем онбординг для настройки Hue Bridge
                OnboardingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Показываем основной интерфейс
                MainContainer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: navigationManager.currentRoute) {
                        navigationManager.togleTabBarVisible()
                    }
            
                if navigationManager.isTabBarVisible {
                    TabBarView()
                       
                }
            }
        }


    }
}
#Preview {
    /// ✅ ОБНОВЛЕНО: .environmentObject -> .environment для @Observable
    MasterView()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
        
}
#Preview {
    /// ✅ ОБНОВЛЕНО: .environmentObject -> .environment для @Observable
    MasterView()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
       
}


//                .onAppear {
//                      //  проверка шрифтов
//                      for family in UIFont.familyNames {
//                          for name in UIFont.fontNames(forFamilyName: family) {
//                          }
//                      }
//                  }
