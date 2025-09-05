//
//  HeaderAddNew.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct HeaderAddNew<RightView: View>: View {
       var title: String
       
        @ViewBuilder let rightView: RightView
        
        var body: some View {
            ZStack {
                // Заголовок по центру
                Text(title)
                  .font(Font.custom("DMSans-Light", size: 20))
                  .kerning(3.4)
                  .foregroundColor(.primColor)
                  .opacity(0.7)
                  .blur(radius: 0.3)
                  .adaptiveOffset(x: -88)
               // Правая кнопка
                rightView
                    .adaptiveOffset(x: 130)
            }
         }
    }

#Preview {
    ZStack {
        BG()
        HeaderAddNew(title: "NEW BULB") {
            DismissButton{
                
            }
        }
    }
}
#Preview {
    AddNewBulb()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=140-1857&m=dev")!)
        .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}
