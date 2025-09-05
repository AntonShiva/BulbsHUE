//
//  Header.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct Header<LeftView1: View,LeftView2: View, RightView1: View,RightView2: View>: View {
   var title: String
    @ViewBuilder let leftView1: LeftView1
    @ViewBuilder let leftView2: LeftView2
    @ViewBuilder let rightView1: RightView1
    @ViewBuilder let rightView2: RightView2
    var body: some View {
        ZStack {
            // Левая кнопка
            leftView1
                .adaptiveOffset(x: -140)
            leftView2
                .adaptiveOffset(x: -83)
            // Заголовок по центру
            Text(title)
                .font(Font.custom("DMSans-Regular", size: 16))
                .kerning(4.3)
                .foregroundColor(.primColor)
              .blur(radius: 0.2)
            
            rightView1
                .adaptiveOffset(x: 91)
           // Правая кнопка
            rightView2
                .adaptiveOffset(x: 142)
        }
     }
}
#Preview("Environment Bulbs with Figma") {
    EnvironmentBulbsView()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=120-2042&m=dev")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
#Preview {
    ZStack {
        BG()
        
        Header(title: "BULB") {
            
            // Левая кнопка - ваше меню
            MenuButton {}
        } leftView2: {
            MenuButton {}
        
    } rightView1: {
        MenuButton {}
    } rightView2: {
        // Правая кнопка - плюс
        AddHeaderButton{}
    }
}
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}


