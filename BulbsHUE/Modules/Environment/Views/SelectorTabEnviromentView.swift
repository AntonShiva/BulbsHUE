//
//  SelectorTabEnviromentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct SelectorTabEnviromentView: View {
    var body: some View {
        ZStack{
            BGSelector()
                .adaptiveFrame(width: 330, height: 103)
            
            if true {
                Duga(color: .primColor)
                    .adaptiveOffset(x: -72)
            } else {
                DugaInvers(color: .primColor)
                    .adaptiveOffset(x: 72)
            }
            LabelText(image: "lightBulb", width: 24, height: 24, text: "Bulbs")
                .adaptiveOffset(x: -72)
            LabelText(image: "bed", width: 32, height: 32, text: "Rooms")
            
                .adaptiveOffset(x: 62)
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
   ZStack {
        BG()
        
       SelectorTabEnviromentView()
    }
   .environmentObject(AppViewModel())
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}



