//
//  SearchResultsSheet.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct SearchResultsSheet: View {
    @EnvironmentObject var nav: NavigationManager
    
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 35,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 35
            )
            .fill(Color(red: 0.02, green: 0.09, blue: 0.13))
            .adaptiveFrame(width: 375, height: 342)
            
            Text("search results")
              .font(Font.custom("DMSans-Light", size: 14))
              .kerning(2.8)
              .multilineTextAlignment(.center)
              .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
              .textCase(.uppercase)
              .adaptiveOffset(y: -130)
            
            // Здесь должен быть список найденных устройств
            VStack(spacing: 8) {
                // Пример найденных устройств - в реальности здесь будет ForEach с данными
                BulbCell(text: "Philips Hue Color", image: "lightBulb", width: 32, height: 32) {
                    nav.showCategoriesSelection()
                }
                
                BulbCell(text: "IKEA TRÅDFRI", image: "lightBulb", width: 32, height: 32) {
                    nav.showCategoriesSelection()
                }
                
                BulbCell(text: "Xiaomi Yeelight", image: "lightBulb", width: 32, height: 32) {
                    nav.showCategoriesSelection()
                }
            }
            .adaptiveOffset(y: -40)
        }
        
    }
}

#Preview {
    SearchResultsSheet()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
