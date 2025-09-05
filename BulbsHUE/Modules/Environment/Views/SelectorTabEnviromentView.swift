//
//  SelectorTabEnviromentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct SelectorTabEnviromentView: View {
    @Environment(NavigationManager.self) private var nav
    
    var body: some View {
        ZStack{
            BGSelector()
                .adaptiveFrame(width: 330, height: 103)
            
            if nav.еnvironmentTab == .bulbs {
                Duga(color: .primColor)
                    .adaptiveOffset(x: -72)
            } else {
                DugaInvers(color: .primColor)
                    .adaptiveOffset(x: 72)
            }
            
            // Bulbs tab - переключает на вкладку bulbs
            Button {
                nav.еnvironmentTab = .bulbs
            } label: {
                LabelText(image: "lightBulb", width: 24, height: 24, text: "Bulbs")
                    .adaptiveOffset(x: -72)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Rooms tab - переключает на вкладку rooms
            Button {
                nav.еnvironmentTab = .rooms
            } label: {
                LabelText(image: "bed", width: 32, height: 32, text: "Rooms")
                    .adaptiveOffset(x: 62)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
#Preview {
    MasterView()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=64-207&t=hGUwQNy3BUo6l6lB-4")!)
        .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}

#Preview {
   ZStack {
        BG()
        
       SelectorTabEnviromentView()
    }
   .environment(NavigationManager.shared)
   .environment(AppViewModel())
   .environment(AppViewModel())
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}



