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
                .adaptiveFrame(width: 330, height: 102)
           
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


