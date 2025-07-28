//
//  Header.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct Header<LeftView: View, RightView: View>: View {
   var title: String
    @ViewBuilder let leftView: LeftView
    @ViewBuilder let rightView: RightView
    
    var body: some View {
        ZStack {
            // Левая кнопка
            leftView
                .adaptiveOffset(x: -140)
            // Заголовок по центру
            Text(title)
                .font(Font.custom("DM Sans", size: 16).weight(.regular))
                .kerning(4.3)
                .foregroundColor(.primColor)
              .blur(radius: 0.2)
           // Правая кнопка
            rightView
                .adaptiveOffset(x: 140)
        }
       
       
    
    }
}

#Preview {
   ZStack {
        BG()
        
        Header(title: "ENVIRONMENT") {
                        // Левая кнопка - ваше меню
                     MenuButton {}
                    } rightView: {
                        // Правая кнопка - плюс
                        AddHeaderButton{}
                    }
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
