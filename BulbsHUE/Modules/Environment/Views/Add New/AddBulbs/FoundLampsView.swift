//
//  FoundДampsView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct FoundLampsView: View {
    var body: some View {
        ZStack{
         BGCircle()
                .adaptiveFrame(width: 256, height: 256)
            
            Image("BigBulb")
                .resizable()
                .scaledToFit()
                .adaptiveFrame(width: 176, height: 170)
                .blur(radius: 1)
                .adaptiveOffset(y: 5)
        }
    }
}

#Preview {
    ZStack {
        BG()
        FoundLampsView()
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2075-220&t=cIMUjKjrvoKSOXgS-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}


