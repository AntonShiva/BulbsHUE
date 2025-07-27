//
//  BGCircle.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct BGCircle: View {
    var body: some View {
        Circle()
            .stroke(.primColor.opacity(0.2), lineWidth: 2.2)
    }
}

#Preview {
    ZStack{
    BG()
        BGCircle()
       
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}


