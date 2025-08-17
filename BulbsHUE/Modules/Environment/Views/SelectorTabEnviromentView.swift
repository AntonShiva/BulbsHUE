//
//  SelectorTabEnviromentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct SelectorTabEnviromentView: View {
    @EnvironmentObject var nav: NavigationManager
    @State private var selectedTab: EnvironmentTab = .bulbs
    
    enum EnvironmentTab {
        case bulbs, rooms
    }
    
    // MARK: - Computed Property для определения активной вкладки
    private var environmentTab: EnvironmentTab? {
        switch nav.currentRoute {
        case .environmentBulbs:
            return .bulbs
        case .environment:
            return .rooms
        default:
            return nil // Не обновляем вкладку для других маршрутов
        }
    }
    
    var body: some View {
        ZStack{
            BGSelector()
                .adaptiveFrame(width: 330, height: 103)
            
            if selectedTab == .bulbs {
                Duga(color: .primColor)
                    .adaptiveOffset(x: -72)
            } else {
                DugaInvers(color: .primColor)
                    .adaptiveOffset(x: 72)
            }
            
            // Bulbs tab - переход на экран выбора сцен
            Button {
                selectedTab = .bulbs
                nav.go(.environmentBulbs)
            } label: {
                LabelText(image: "lightBulb", width: 24, height: 24, text: "Bulbs")
                    .adaptiveOffset(x: -72)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Rooms tab - остается на текущем экране
            Button {
                selectedTab = .rooms
                nav.go(.environment)
            } label: {
                LabelText(image: "bed", width: 32, height: 32, text: "Rooms")
                    .adaptiveOffset(x: 62)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            // Устанавливаем правильную вкладку в зависимости от текущего маршрута
            updateSelectedTab()
        }
        .onChange(of: nav.currentRoute) { _ in
            // Обновляем выбранную вкладку при изменении маршрута
            updateSelectedTab()
        }
    }
    
    // MARK: - Private Methods
    private func updateSelectedTab() {
        // Обновляем selectedTab только если маршрут относится к Environment
        if let tab = environmentTab {
            selectedTab = tab
        }
        // Если environmentTab возвращает nil - не изменяем текущую вкладку
    }
}
#Preview {
    MasterView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=64-207&t=hGUwQNy3BUo6l6lB-4")!)
        .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}

#Preview {
   ZStack {
        BG()
        
       SelectorTabEnviromentView()
    }
   .environmentObject(NavigationManager.shared)
   .environmentObject(AppViewModel())
   .environmentObject(AppViewModel())
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}



