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
        ZStack() {
        
         Image(image)
                .resizable()
                .scaledToFit()
                .adaptiveFrame(width: width, height: height)
                .adaptiveOffset(x: -28, y: 0)
            
            Text(text)
              .font(Font.custom("DM Sans", size: 12))
              .tracking(2.04)
              .foregroundColor(.primColor)
              .textCase(.uppercase)
              .adaptiveOffset(x: 18, y: 0)
        }
        .adaptiveFrame(width: 80, height: 24);
      }
    }

#Preview {
    ZStack {
        Color.black
        LabelText(image: "lightBulb", width: 24, height: 24, text: "Bulbs")
    }
}
