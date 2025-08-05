//
//  EnvironmentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var viewModel: AppViewModel
    var body: some View {
        ZStack {
            BG()
            
            Header(title: "ENVIRONMENT") {
                // Левая кнопка - ваше меню
                MenuButton { }
            } rightView: {
                // Правая кнопка - плюс
                AddHeaderButton {
                    nav.go(.addNewBulb)
                }
            }
            .adaptiveOffset(y: -330)
            
            SelectorTabEnviromentView()
                .adaptiveOffset(y: -264)
            
            Text("You don't have \nany bulbs yet")
                .font(Font.custom("DMSans-Regular", size: 16))
                .kerning(3.2)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.75, green: 0.85, blue: 1))
                .opacity(0.3)
                .textCase(.uppercase)
            
            AddButton(text: "add bulb", width: 427, height: 295) {
                nav.go(.addNewBulb)
            }
            .adaptiveOffset(y: 195)
        }
       
    }
}
#Preview {
    MasterView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=64-207&t=hGUwQNy3BUo6l6lB-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

#Preview {
    @Previewable @EnvironmentObject var viewModel: AppViewModel
    EnvironmentView(viewModel: _viewModel)
        .environmentObject(AppViewModel())
}
