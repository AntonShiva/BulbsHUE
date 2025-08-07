//
//  MenuButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct MenuButton: View {
    var action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            ZStack{
                BGCircle()
                    .adaptiveFrame(width: 47, height: 47)
                MenuIcon()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        BG()
        
        MenuButton(){
            
        }
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}
