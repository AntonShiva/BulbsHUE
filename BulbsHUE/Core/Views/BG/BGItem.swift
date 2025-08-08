//
//  BGItem.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/8/25.
//

import SwiftUI

struct BGItem: View {
   
        let baseColor: Color
        
        var body: some View {
            RoundedRectangle(cornerRadius: 25)
                .fill(
                    // Основной горизонтальный градиент
                    LinearGradient(
                        gradient: Gradient(stops: [
                            // Левый край - светлее и менее насыщенный
                            .init(color: Color(
                                hue: baseColor.hue,
                                saturation: baseColor.saturation * 0.75,
                                brightness: min(baseColor.brightness * 1.15, 1.0)
                            ), location: 0.0),
                            
                            // Левая четверть - переход к основному
                            .init(color: Color(
                                hue: baseColor.hue,
                                saturation: baseColor.saturation * 0.85,
                                brightness: min(baseColor.brightness * 1.1, 1.0)
                            ), location: 0.15),
                            
                            // Центр-лево - почти полная яркость
                            .init(color: Color(
                                hue: baseColor.hue,
                                saturation: baseColor.saturation * 0.95,
                                brightness: baseColor.brightness
                            ), location: 0.35),
                            
                            // Центр - максимальная яркость
                            .init(color: baseColor, location: 0.5),
                            
                            // Центр-право - начало затемнения
                            .init(color: Color(
                                hue: baseColor.hue,
                                saturation: baseColor.saturation,
                                brightness: baseColor.brightness * 0.95
                            ), location: 0.65),
                            
                            // Правая четверть - заметное затемнение
                            .init(color: Color(
                                hue: baseColor.hue,
                                saturation: min(baseColor.saturation * 1.1, 1.0),
                                brightness: baseColor.brightness * 0.85
                            ), location: 0.85),
                            
                            // Правый край - самый темный и насыщенный
                            .init(color: Color(
                                hue: baseColor.hue,
                                saturation: min(baseColor.saturation * 1.2, 1.0),
                                brightness: baseColor.brightness * 0.75
                            ), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    // Радиальный градиент для затемнения углов
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.black.opacity(0.15)
                                ]),
                                center: .center,
                                startRadius: 50,
                                endRadius: 180
                            )
                        )
                )
        }
    }


#Preview {
    ZStack {
        Color.black
        BGItem(baseColor: .purple)
            .frame(width: 300, height: 150)
        
      
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=Oz8YTfvXva0QJfVZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}



// Расширение для работы с HSB цветами
extension Color {
    var hue: Double {
        let uiColor = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(h)
    }
    
    var saturation: Double {
        let uiColor = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(s)
    }
    
    var brightness: Double {
        let uiColor = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(b)
    }
}



