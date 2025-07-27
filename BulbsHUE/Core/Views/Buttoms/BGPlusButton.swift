//
//  BGPlusButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct BGPlusButton: View {
    var body: some View {
        ZStack() {
             BGCircleButton()
                  
            
            ZStack {
                     Circle()
                    .stroke(Color(red: 0.79, green: 1, blue: 1).opacity(0.2), lineWidth: 2.2)
                     .adaptiveFrame(width: 30, height: 30)
                     
                     Image(systemName: "plus")
                    .font(.system(size: 13)).fontWeight(.heavy)
                         .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.9))
                 }
            .adaptiveOffset(x: -81, y: -1)
                   
        }
    }
}

#Preview {
    BGPlusButton()
}
