//
//  AddBulbButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct AddButton: View {
    var text: String
    var width: CGFloat
    var height: CGFloat
    var action: () -> Void
    
      var body: some View {
          Button {
              action()
          } label: {
              ZStack() {
                  BGPlusButton()
                      .adaptiveFrame(width: width, height: height)
                  
                  Text(text)
                      .font(Font.custom("DM Sans", size: 16.5) .weight(.medium))
                    .kerning(6)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .textCase(.uppercase)
                    .adaptiveOffset(x: 20,y: -1.5)
                    .blur(radius: 0.5)
              }
          }
          .buttonStyle(PlainButtonStyle())
       }
    }

#Preview {
    ZStack {
        BG()
        
        AddButton(text: "add bulb", width: 427, height: 295) {
            
        }
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}

