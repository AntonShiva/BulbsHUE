//
//  TabBarButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI

//
//struct TabBarButton: View {
//    let activeIcon: Image
//    let inactiveIcon: Image
//    let title: String
////    let route: Router
////    @Binding var currentView: Router
//    
//    // Colors from Figma
//    private let activeColor = Color(red: 0.33, green: 0.47, blue: 1) // Active color
//    private let inactiveColor = Color(red: 0.41, green: 0.46, blue: 0.65) // Inactive color
//    
//    private var isSelected: Bool {
////        currentView == route
//        true
//    }
//    
//    var body: some View {
//        Button {
////            currentView = route
//        } label: {
//            VStack(spacing: 2) {
//                // Icon
//                (isSelected ? activeIcon : inactiveIcon)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 48, height: 48)
//                
//                // Title
//                Text(title)
//                    .font(.custom("Unbounded", size: 10))
//                    .fontWeight(.regular)
//                    .foregroundColor(isSelected ? activeColor : inactiveColor)
//                    .opacity(isSelected ? 1.0 : 0.8)
//                    .kerning(2.0) // 20% letter spacing approximation
//                    .multilineTextAlignment(.center)
//                    .offset(x: title == "MIXER" ? 4 : 0)
//            }
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}

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
