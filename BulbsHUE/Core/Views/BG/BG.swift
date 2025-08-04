//
//  BG.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 25.07.2025.
//

import SwiftUI

struct BG: View {
    var body: some View {
   Image("BG")
            .resizable()
            .scaledToFit()
            .frame(width: UIScreen.width, height: UIScreen.height)
            .edgesIgnoringSafeArea(.all)
    }
}

struct BGLight: View {
    var body: some View {
   Image("BGLigth")
            .resizable()
            .scaledToFit()
            .frame(width: UIScreen.width, height: UIScreen.height)
            .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    BG()
}

#Preview {
    MasterView()
}


//struct MeshLikeGradientView: View {
//    var body: some View {
//        ZStack {
//            
//            // Нижний фон (чёрно-синий)
//            RadialGradient(
//                gradient: Gradient(colors: [Color(hex: "#010108"), .black]),
//                center: UnitPoint(x: 0.5, y:0.75),
//                startRadius: 0,
//                endRadius: 500
//            )
//            .ignoresSafeArea()
//            // Верхняя синяя область
//            RadialGradient(
//                gradient: Gradient(colors: [Color(hex: "#012e6b"), .clear]),
//                center: UnitPoint(x: 0.75, y: 0.21),
//                startRadius: 0,
//                endRadius: 450
//            )
//            .blendMode(.plusLighter)
//            .blur(radius: 20)
//            .ignoresSafeArea()
//
//            // Верхняя зелёная область
//            RadialGradient(
//                gradient: Gradient(colors: [Color(hex: "#02665c").opacity(0.8), Color(hex: "#02665c").opacity(0.5),.clear]),
//                center: UnitPoint(x: 0.25, y: 0.1),
//                startRadius: 50,
//                endRadius: 250
//            )
//            .frame(width: 400, height: 350)
//            .blendMode(.plusLighter)
//            .blur(radius: 40)
//            .ignoresSafeArea()
//            .rotationEffect(.degrees(20))
//            .offset(x: -60, y: -200)
//
//            // Нижняя левая затемнённая бирюза
//            RadialGradient(
//                gradient: Gradient(colors: [Color(hex: "#013542").opacity(0.6), .clear]),
//                center: UnitPoint(x: 1.1, y: 0.65),
//                startRadius: 0,
//                endRadius: 300
//            )
//            .blendMode(.plusLighter)
//            .ignoresSafeArea()
//        }
//    }
//}
//
//extension Color {
//    init(hex: String) {
//        let scanner = Scanner(string: hex)
//        _ = scanner.scanString("#")
//        
//        var rgb: UInt64 = 0
//        scanner.scanHexInt64(&rgb)
//
//        let r = Double((rgb >> 16) & 0xFF) / 255
//        let g = Double((rgb >> 8) & 0xFF) / 255
//        let b = Double(rgb & 0xFF) / 255
//
//        self.init(red: r, green: g, blue: b)
//    }
//}
