//
//  TabBarView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct TabBarView: View {

    var body: some View {
        ZStack {
            // Тень под панель
         Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(height: 104)
                    .frame(width: UIScreen.width)
                    .background(Color(red: 0.02, green: 0.04, blue: 0.05))
                    .shadow(color: .black.opacity(0.25), radius: 7.5, x: 0, y: -10)
            
                Rectangle()
                  .foregroundColor(.clear)
                  .adaptiveFrame(height: 1.5)
                  .frame(width: UIScreen.width)
                  .background(Color(red: 0.6, green: 0.6, blue: 0.6))
                  .opacity(0.25)
                  .adaptiveOffset(y: -51.5)
            
            HStack {
                TabBarButton(image: "envir", title: "environment", route: .environment)
                .frame(maxWidth: .infinity)
                
                TabBarButton(image: "schedule", title: "schedule", route: .schedule)
                .frame(maxWidth: .infinity)
                
                TabBarButton(image: "music", title: "music", route: .music)
                .frame(maxWidth: .infinity)
            }
            .adaptiveFrame(height: 104)
            
           
             
        }
        .frame(width: UIScreen.width)
    }
}


#Preview {
    TabBarView()
}
