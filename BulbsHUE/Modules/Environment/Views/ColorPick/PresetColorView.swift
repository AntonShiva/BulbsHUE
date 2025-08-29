//
//  PresetColorView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/29/25.
//

import SwiftUI
import Combine

struct PresetColorView: View {
    @EnvironmentObject var nav: NavigationManager
   
    var body: some View {
        ZStack{
            BG()
           navigationHeader
                .adaptiveOffset(y: -328)
            
            
        }
    }
    /// Верхняя навигационная панель с кнопками и заголовком
    private var navigationHeader: some View {
        Header(title: "SHENE NAME") {
            ChevronButton {
                nav.go(.environment)
            }
            .rotationEffect(.degrees(180))
    } leftView2: {
        EmptyView()
    } rightView1: {
        EmptyView()
    } rightView2: {
      
        // Центральная кнопка - FAV
        Button {
            
        } label: {
            ZStack {
                BGCircle()
                    .adaptiveFrame(width: 48, height: 48)
                
                // Heart icon
                Image(systemName:  "heart")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundColor(.primColor)
               
            }
        }
        .buttonStyle(PlainButtonStyle())
        .adaptiveOffset(x: -3)
    }
    }
    
    
}

enum PresetColor: CaseIterable {
    case statics
    case dynamic
}

@MainActor
class PresetColorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: PresetColor = .statics
}


#Preview {
    PresetColorView()
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=123-2559&t=2MO1qF5YMTp0ngJy-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
