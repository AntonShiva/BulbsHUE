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
//    let route: Router
//    @Binding var currentView: Router
    
    // Colors from Figma
    private let activeColor = Color(red: 0.79, green: 1, blue: 1) // Active color
    private let inactiveColor = Color(red: 0.41, green: 0.46, blue: 0.65) // Inactive color
    
    private var isSelected: Bool {
//        currentView == route
        true
    }
    
    var body: some View {
        Button {
//            currentView = route
        } label: {
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
                    .font(Font.custom("DMSans-9ptRegular_Light", size: 10))
                  .kerning(2.2)
                  .multilineTextAlignment(.center)
                  .foregroundColor(isSelected ? activeColor : inactiveColor)
                    .opacity(isSelected ? 1.0 : 0.8)
                    .textCase(.uppercase)
                    
//                    .offset(x: title == "MIXER" ? 4 : 0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
              //  проверка шрифтов 
              for family in UIFont.familyNames {
                  print("== \(family)")
                  for name in UIFont.fontNames(forFamilyName: family) {
                      print("   - \(name)")
                  }
              }
          }
    }
}
#Preview {
    ZStack {
        BG()
        TabBarButton(image: "envir", title: "environment")
    }
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
