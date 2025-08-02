//
//  AddNewBulb.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 02.08.2025.
//

import SwiftUI

struct AddNewBulb: View {
    var body: some View {
        ZStack {
            BG()
            Image("BigBulb")
                .resizable()
                .scaledToFit()
                .adaptiveFrame(width: 142, height: 136)
                .adaptiveOffset(y: -200)
            
            ZStack{
                Rectangle()
                  .foregroundColor(.clear)
                  .adaptiveFrame(width: 244, height: 68)
                  .background(Color(red: 0.4, green: 0.49, blue: 0.68))
                  .cornerRadius(14)
                  .blur(radius: 44.55)
                  .rotationEffect(Angle(degrees: 13.02))
                
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 280, height: 72)
                .cornerRadius(50)
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .inset(by: 0.5)
                        .stroke(Color(red: 0.32, green: 0.44, blue: 0.46), lineWidth: 1)
                )
                
                Text("use serial number")
                    .font(Font.custom("DMSans-9ptRegular_Light", size: 16))
                  .kerning(2.4)
                  .multilineTextAlignment(.center)
                  .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                  .textCase(.uppercase)
        }
            
            Text("on the lamp or label")
              .font(
                Font.custom("DM Sans", size: 10)
                  .weight(.light)
              )
              .kerning(1.5)
              .multilineTextAlignment(.center)
              .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
              .textCase(.uppercase)
            
            HStack {
                Rectangle()
                  .frame(width: 112, height: 1)
                  .overlay(
                    Rectangle()
                      .stroke(Color(red: 0.79, green: 1, blue: 1), lineWidth: 1)
                  )
                  .opacity(0.4)
                
                Text("or")
                  .font(
                    Font.custom("DM Sans", size: 16)
                      .weight(.light)
                  )
                  .kerning(2.4)
                  .multilineTextAlignment(.center)
                  .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                  .textCase(.uppercase)
                Rectangle()
                  .frame(width: 112, height: 1)
                  .overlay(
                    Rectangle()
                      .stroke(Color(red: 0.79, green: 1, blue: 1), lineWidth: 1)
                  )
                  .opacity(0.4)
             }
            .adaptiveOffset(y: 200)
        }
    }
}

#Preview {
    AddNewBulb()
}


