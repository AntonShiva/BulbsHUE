//
//  ContentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI

struct MasterView: View {
    var body: some View {
        ZStack {
            BG()
             
            TabBarButton(image: "envir", title: "environment")
         
        }
    }
}

#Preview {
    MasterView()
}
