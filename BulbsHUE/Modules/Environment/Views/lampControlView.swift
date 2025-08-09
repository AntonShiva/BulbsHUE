//
//  lampControlView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/8/25.
//

import SwiftUI

struct lampControlView: View {
    var body: some View {
        ZStack{
            BGItem(baseColor: .purple)
                .adaptiveFrame(width: 278, height: 140)
            
            Image("f2")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
              .adaptiveFrame(width: 32, height: 32)
              .adaptiveOffset(x: -100, y: -42)
            
            Text("bulb name")
              .font(Font.custom("DMSans-Regular", size: 20))
              .kerning(4)
              .foregroundColor(.white)
              .textCase(.uppercase)
              .adaptiveOffset(x: -45, y: -3)
            
            Text("bulb type")
              .font(Font.custom("DMSans-Light", size: 14))
              .kerning(2.8)
              .foregroundColor(.white)
              .textCase(.uppercase)
              .adaptiveOffset(x: -70, y: 19)
            
           Rectangle()
                .fill( Color(red: 0.79, green: 1, blue: 1) )
                .adaptiveFrame(width: 153, height: 2)
              .opacity(0.2)
              .adaptiveOffset(x: -42, y: 33)
            
            Image("tr1")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
              .adaptiveFrame(width: 16, height: 16)
              .adaptiveOffset(x: -108, y: 46)
            
            Text("living room")
                .font(Font.custom("DMSans-Light", size: 12))
              .kerning(2.4)
              .foregroundColor(.white)
              .textCase(.uppercase)
              .adaptiveOffset(x: -42, y: 46)
            
            CustomToggle(isOn: .constant(true))
                .adaptiveOffset(x: 95, y: 42)
            
            ZStack {
                BGCircle()
                  .adaptiveFrame(width: 36, height: 36)
                  
                
                Image(systemName: "ellipsis")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: 90))
                   
            }
            .adaptiveOffset(x: 111, y: -43)
        }
        
    }
}

#Preview {
    lampControlView()
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=Oz8YTfvXva0QJfVZ-4")!)
       
}
