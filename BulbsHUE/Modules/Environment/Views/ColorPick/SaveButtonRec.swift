//
//  SaveButtonRec.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/30/25.
//

import SwiftUI

struct SaveButtonRec: View {
   
    var action: () -> Void
    
      var body: some View {
          Button {
              action()
          } label: {
              ZStack() {
                  Image("BGSaveRecButton")
                      .resizable()
                      .scaledToFit()
                      .adaptiveFrame(width: 375, height: 2340)
                  
                  Text("SAVE")
                      .font(Font.custom("DMSans-Bold", size: 16.5))
                    .kerning(3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .textCase(.uppercase)
                    .adaptiveOffset(y: 26.5)
                    .blur(radius: 0.5)
              }
          }
          .buttonStyle(PlainButtonStyle())
       }
    }


#Preview {
    ZStack {
        BG()
        SaveButtonRec{
            
        }
        .adaptiveOffset(y: -69)
        
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2245-2&t=DWpNpBaXqdyvmEx4-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
