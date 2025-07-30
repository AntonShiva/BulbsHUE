//
//  ContentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI

struct MasterView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        ZStack(alignment: .bottom) {
            BG()
            
            if appViewModel.showSetup {
                // Показываем онбординг для настройки Hue Bridge
                OnboardingView(appViewModel: appViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Показываем основной интерфейс
                MainContainer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                TabBarView()
                    .adaptiveOffset(y: 20)
            }
        }
    }
}

#Preview {
    MasterView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
        .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}

//.onAppear {
//      //  проверка шрифтов
//      for family in UIFont.familyNames {
//          print("== \(family)")
//          for name in UIFont.fontNames(forFamilyName: family) {
//              print("   - \(name)")
//          }
//      }
//  }
