//
//  MenuView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/13/25.
//

import SwiftUI

struct MenuView: View {
    /// Базовый цвет для фона компонента
    let baseColor: Color
    
    init(baseColor: Color = .purple) {
      self.baseColor = baseColor
    }
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 35,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 35
            )
            .fill(Color(red: 0.02, green: 0.09, blue: 0.13))
            .adaptiveFrame(width: 375, height: 678)
            ZStack{
                BGItem(baseColor: baseColor)
                    .adaptiveFrame(width: 278, height: 140)
                
                Image("floor")
                    .resizable()
                    .scaledToFit()
                    .adaptiveFrame(width: 32, height: 32)
            }
            .adaptiveOffset(y: -173)
        }
        .adaptiveOffset(y: 67)
    }
}
#Preview {
    MenuView()
     
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=120-879&t=AxBzQxdU1p2JSkT2-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
       
}
#Preview {
    MenuView()
}

