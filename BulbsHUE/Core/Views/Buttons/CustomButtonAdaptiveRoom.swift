//
//  CustomButtonAdaptiveRoom.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

struct CustomButtonAdaptiveRoom: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    let image: String
    let cornerInset: CGFloat = 20 // Можно настроить под ваше изображение
    var offsetX: CGFloat
    var offsetY: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Растягиваемый фон
                Image(image)
                    .resizable(capInsets: EdgeInsets(
                        top: cornerInset,
                        leading: cornerInset,
                        bottom: cornerInset,
                        trailing: cornerInset
                    ), resizingMode: .stretch)
                    .frame(width: width, height: height)
                
                Text(text)
                    .font( Font.custom("DMSans-Bold", size: 16.5))
                  .kerning(3.2)
                  .multilineTextAlignment(.center)
                  .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                  .textCase(.uppercase)
                  .adaptiveOffset(x: offsetX, y: offsetY)
                  .blur(radius: 0.5)
            }
        }
        .frame(width: width, height: height)
        .buttonStyle(PlainButtonStyle())
    }
}
#Preview {
    CustomButtonAdaptiveRoom(text: "rename", width: 390, height: 266, image: "BGRename", offsetX: 0, offsetY: 17) {
    
    }
}


