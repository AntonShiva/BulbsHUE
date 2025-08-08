//
//  EnvironmentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var viewModel: AppViewModel
    var body: some View {
        ZStack {
            BG()
            
            Header(title: "ENVIRONMENT") {
                // Левая кнопка - ваше меню
                MenuButton { }
            } rightView: {
                // Правая кнопка - плюс
                AddHeaderButton {
                    nav.go(.addNewBulb)
                }
            }
            .adaptiveOffset(y: -330)
            Frame9()
            
            SelectorTabEnviromentView()
                .adaptiveOffset(y: -264)
            
            Text("You don't have \nany bulbs yet")
                .font(Font.custom("DMSans-Regular", size: 16))
                .kerning(3.2)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.75, green: 0.85, blue: 1))
                .opacity(0.3)
                .textCase(.uppercase)
            
            AddButton(text: "add bulb", width: 427, height: 295) {
                nav.go(.addNewBulb)
            }
            .adaptiveOffset(y: 195)
        }
       
    }
}
#Preview {
    MasterView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=64-207&t=hGUwQNy3BUo6l6lB-4")!)
        .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}

#Preview {
    @Previewable @EnvironmentObject var viewModel: AppViewModel
    EnvironmentView(viewModel: _viewModel)
        .environmentObject(AppViewModel())
}
struct Frame9: View {
  var body: some View {
    ZStack() {
      ZStack() {
        Rectangle()
          .foregroundColor(.clear)
          .frame(width: 278, height: 140)
          .background(Color(red: 0.60, green: 0.60, blue: 0.93))
          .cornerRadius(20)
          .offset(x: 0, y: 0)
        Ellipse()
          .foregroundColor(.clear)
          .frame(width: 266.72, height: 444.10)
          .background(Color(red: 0.55, green: 0.19, blue: 0.69))
          .offset(x: -76.64, y: 157.68)
          .blur(radius: 93.80)
        Ellipse()
          .foregroundColor(.clear)
          .frame(width: 181, height: 251)
          .background(Color(red: 0.80, green: 0.38, blue: 0.95))
          .offset(x: -33.50, y: -7.50)
          .blur(radius: 93.80)
      }
      .frame(width: 278, height: 140)
      .cornerRadius(26)
      .offset(x: 0, y: 0)
    }
    .frame(width: 278, height: 140)
    .shadow(
      color: Color(red: 0, green: 0, blue: 0, opacity: 0.20), radius: 20
    );
  }
}
