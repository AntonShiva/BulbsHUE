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
                .adaptiveFrame(width: 330, height: 100)
            
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
            
                .adaptiveOffset(x: 72)
        }
    }
}

#Preview {
   ZStack {
        BG()
        
       SelectorTabEnviromentView()
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}



