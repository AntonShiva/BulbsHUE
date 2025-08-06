//
//  AddNewBulb.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 02.08.2025.
//

import SwiftUI

struct AddNewBulb: View {
    @EnvironmentObject var nav: NavigationManager
    
    var body: some View {
        ZStack {
            BGLight()
            
            HeaderAddNew(title: "NEW BULB"){
                DismissButton{
                    nav.resetAddBulbState()
                    nav.go(.environment)
                }
            }
            .adaptiveOffset(y: -323)
            if !nav.isSearching {
            Image("BigBulb")
                .resizable()
                .scaledToFit()
                .adaptiveFrame(width: 176, height: 170)
                .adaptiveOffset(y: -181)
                .blur(radius: 1)
            
            
            Text("important")
                .font( Font.custom("DMSans-Bold", size: 14))
                .kerning(2.1)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
            
                .adaptiveOffset(y: -83)
            
            Text("make sure the lights \nand smart plugs you want to add \nare connected to power")
                .font( Font.custom("DMSans-Light", size: 12))
                .kerning(1.8)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .adaptiveOffset(y: -40)
            
            ZStack{
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 244, height: 68)
                    .background(Color(red: 0.4, green: 0.49, blue: 0.68))
                    .cornerRadius(14)
                    .blur(radius: 44.55)
                    .rotationEffect(Angle(degrees: 13.02))
                
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 280, height: 72)
                    .cornerRadius(50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 50)
                            .inset(by: 0.5)
                            .stroke(Color(red: 0.32, green: 0.44, blue: 0.46), lineWidth: 1)
                    )
                
                Text("use serial number")
                    .font(Font.custom("DMSans-Light", size: 16))
                    .kerning(2.6)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                
            }
            .adaptiveOffset(y: 96)
            
            Text("on the lamp or label")
                .font(Font.custom("DMSans-Light", size: 10))
                .kerning(1.5)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
            
                .adaptiveOffset(y: 147)
            
            
            HStack {
                Rectangle()
                    .adaptiveFrame(width: 115, height: 1)
                    .overlay(
                        Rectangle()
                            .stroke(Color(red: 0.79, green: 1, blue: 1), lineWidth: 1)
                    )
                    .opacity(0.4)
                
                Text("or")
                    .font(Font.custom("DMSans-Light", size: 16))
                    .kerning(2.4)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                
                Rectangle()
                    .adaptiveFrame(width: 115, height: 1)
                    .overlay(
                        Rectangle()
                            .stroke(Color(red: 0.79, green: 1, blue: 1), lineWidth: 1)
                    )
                    .opacity(0.4)
            }
            .adaptiveOffset(y: 191)
            
            CostumButton(text: "search in network", width: 377, height: 291) {
                nav.startSearch()
            }
            .adaptiveOffset(y: 290)
            
            } else {
                FoundLampsView()
                    .adaptiveOffset(y: -162)
                SearchResultsSheet()
                    .adaptiveOffset(y: 235)
                if nav.showSelectCategories {
                    SelectCategoriesSheet()
                }
            }
           
        }
        .textCase(.uppercase)
    }
}

#Preview {
    AddNewBulb()
        .environmentObject(NavigationManager.shared)
//        .environmentObject(AppViewModel())
//        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=144-1954&m=dev")!)
//        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
#Preview {
    AddNewBulb()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=140-1857&m=dev")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}


