//
//  TupeCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct TupeCell: View {
    var text: String
    var image: String
   
    var width: CGFloat
    var height: CGFloat
   
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 332, height: 64)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(15)
                .opacity(0.1)
            
            Image(image)
                   .resizable()
                   .scaledToFit()
                   .adaptiveFrame(width: width, height: height)
                   .adaptiveOffset(x: -133)
            
            Text(text)
              .font(Font.custom("DMSans-Regular", size: 14))
              .kerning(3)
              .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
              .textCase(.uppercase)
              .adaptiveOffset(x: -43)
            
            SelectCategoryButton{
                
            }
            .adaptiveOffset(x: 135)
        }
        
    }
}

#Preview {
    ZStack {
        SearchResultsSheet()
        TupeCell(text: "Bulb name", image: "lightBulb", width: 32, height: 32)
    }
    .environmentObject(NavigationManager.shared)
    .environmentObject(AppViewModel())
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

#Preview {
    SearchResultsSheet()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
