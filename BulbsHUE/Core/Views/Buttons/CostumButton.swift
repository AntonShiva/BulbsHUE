//
//  CostumButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct CostumButton: View {
    var text: String
    var width: CGFloat
    var height: CGFloat
    var action: () -> Void
    
      var body: some View {
          Button {
              action()
          } label: {
              ZStack() {
                  BGCustomButton()
                      .adaptiveFrame(width: width, height: height)
                  
                  Text(text)
                      .font(
                        Font.custom("DMSans-Light", size: 16.5))
                      .kerning(2.4)
                      .multilineTextAlignment(.center)
                      .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .textCase(.uppercase)
                    .adaptiveOffset(y: -1.5)
                    .blur(radius: 0.5)
              }
          }
          .buttonStyle(PlainButtonStyle())
       }
    }
#Preview {
    AddNewBulb()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=140-1857&m=dev")!)
        .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}
#Preview {
    
    CostumButton(text: "add bulb", width: 427, height: 295) {
        
    }
}
