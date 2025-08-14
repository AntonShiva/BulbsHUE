//
//  CustomButtonAdaptive.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/14/25.
//

import SwiftUI

struct CustomButtonAdaptive: View {
    let text: String
    let width: CGFloat
    let height: CGFloat
    let image: String
    let cornerInset: CGFloat = 20 // Можно настроить под ваше изображение
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
                    .font(
                      Font.custom("DMSans-Light", size: 16.5))
                    .kerning(2.4)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                  .textCase(.uppercase)
                  .adaptiveOffset(y: 17)
                  .blur(radius: 0.5)
            }
        }
        .frame(width: width, height: height)
        .buttonStyle(PlainButtonStyle())
    }
}
#Preview {
    CustomButtonAdaptive(text: "rename", width: 390, height: 266, image: "BGRename") {
    
    }
}
