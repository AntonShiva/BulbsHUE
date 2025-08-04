//
//  LabelText.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI

struct LabelText: View {
    var image: String
   
    var width: CGFloat
    var height: CGFloat
    var text: String
      var body: some View {
        HStack(spacing: 12) {
        
         Image(image)
                .resizable()
                .scaledToFit()
                .adaptiveFrame(width: width, height: height)
                
            
            Text(text)
              .font(Font.custom("DMSans-Light", size: 12))
              .tracking(2.04)
              .foregroundColor(.primColor)
              .textCase(.uppercase)
              
        }
        .adaptiveFrame(width: 95, height: 24)
      }
    }

#Preview {
    ZStack {
        Color.black
        LabelText(image: "lightBulb", width: 24, height: 24, text: "Bulbs")
    }
}
