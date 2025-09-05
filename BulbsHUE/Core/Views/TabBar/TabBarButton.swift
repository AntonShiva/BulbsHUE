//
//  TabBarButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI

//
struct TabBarButton: View {
    let image: String
   
    let title: String
    let route: Router
//    @Binding var currentView: Router
    @Environment(NavigationManager.self) private var nav
    
    // Colors from Figma
    private let activeColor = Color(red: 0.79, green: 1, blue: 1) // Active color
    private let inactiveColor = Color(red: 0.6, green: 0.6, blue: 0.6) // Inactive color
    
    private var isSelected: Bool {
        nav.currentRoute == route
    }
    
    var body: some View {
        Button {
            nav.go(route)
        } label: {
             ZStack {
                
                  Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 112, height: 1)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .adaptiveOffset(y: -51.5)
                    .opacity(isSelected ? 1.0 : 0)
                
                VStack(spacing: 9) {
                    // Icon
                    Image(image)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(isSelected ? activeColor : inactiveColor)
                        .adaptiveFrame(width: 40, height: 40)
                    
                    // Title
                    Text(title)
                        .font(Font.custom("DMSans-Light", size: 10))
                        .kerning(2.2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(isSelected ? activeColor : inactiveColor)
                        .opacity(isSelected ? 1.0 : 0.8)
                        .textCase(.uppercase)
                    
                    //                    .offset(x: title == "MIXER" ? 4 : 0)
                }
                .adaptiveFrame(height: 104)
            }
        }
        .buttonStyle(PlainButtonStyle())
      
    }
}
#Preview {
    ZStack {
        BG()
        TabBarView()
            .adaptiveOffset(y: 330)
    }
    .environment(NavigationManager.shared)
}
#Preview {
    ZStack {
        BG()
        TabBarButton(image: "envir", title: "environment", route: .environment)
    }
    .environment(NavigationManager.shared)
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&m=dev")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}

//#Preview {
//    struct PreviewWrapper: View {
//        @State private var selectedRoute: Router = .mixer
//        
//        var body: some View {
//            HStack(spacing: 50) {
//                TabBarButton(
//                    activeIcon: Image("musAct"),
//                    inactiveIcon: Image("mus"),
//                    title: "MIXER",
//                    route: .mixer,
//                    currentView: $selectedRoute
//                )
//                
//                TabBarButton(
//                    activeIcon: Image("webAct"),
//                    inactiveIcon: Image("web"),
//                    title: "WEB",
//                    route: .web,
//                    currentView: $selectedRoute
//                )
//                
//                TabBarButton(
//                    activeIcon: Image("gamAct"),
//                    inactiveIcon: Image("gam"),
//                    title: "GAMES",
//                    route: .games,
//                    currentView: $selectedRoute
//                )
//            }
//            .padding()
//            .background(Color.gray.opacity(0.2))
//        }
//    }
//    
//    return PreviewWrapper()
//}
