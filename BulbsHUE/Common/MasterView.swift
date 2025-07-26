//
//  ContentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI

struct MasterView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            BG()
            MainContainer()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabBarView()
                .adaptiveOffset(y: 20)
        }
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
    MasterView()
        .environmentObject(NavigationManager.shared)
}
