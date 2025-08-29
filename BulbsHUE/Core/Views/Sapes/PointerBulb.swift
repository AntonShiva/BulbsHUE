//
//  PointerBulb.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/29/25.
//

import SwiftUI

struct PointerBulb: View {
    var color: Color
    var body: some View {
        ZStack {
            PointerBulbPath()
                .fill(color)
                .adaptiveFrame(width: 43, height: 57)
                .opacity(0.9)
                .shadow(color: Color.black.opacity(0.4), radius: 10)
            
            PointerBulbPath()
                .stroke(Color(red: 0.79, green: 0.78, blue: 0.67), style: StrokeStyle(
                 lineWidth: 2
                )).opacity(0.5)
                .adaptiveFrame(width: 43, height: 57)
        }
    }
}

struct PointerBulbPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.87976*width, y: 0.4141*height))
        path.addCurve(to: CGPoint(x: 0.56422*width, y: 0.87032*height), control1: CGPoint(x: 0.87976*width, y: 0.54208*height), control2: CGPoint(x: 0.67184*width, y: 0.76401*height))
        path.addCurve(to: CGPoint(x: 0.43835*width, y: 0.87032*height), control1: CGPoint(x: 0.53104*width, y: 0.90309*height), control2: CGPoint(x: 0.47152*width, y: 0.90309*height))
        path.addCurve(to: CGPoint(x: 0.12281*width, y: 0.4141*height), control1: CGPoint(x: 0.33072*width, y: 0.76401*height), control2: CGPoint(x: 0.12281*width, y: 0.54208*height))
        path.addCurve(to: CGPoint(x: 0.50128*width, y: 0.10145*height), control1: CGPoint(x: 0.12281*width, y: 0.24143*height), control2: CGPoint(x: 0.29226*width, y: 0.10145*height))
        path.addCurve(to: CGPoint(x: 0.87976*width, y: 0.4141*height), control1: CGPoint(x: 0.71031*width, y: 0.10145*height), control2: CGPoint(x: 0.87976*width, y: 0.24143*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.50128*width, y: 0.11594*height))
        path.addCurve(to: CGPoint(x: 0.86222*width, y: 0.4141*height), control1: CGPoint(x: 0.70062*width, y: 0.11594*height), control2: CGPoint(x: 0.86222*width, y: 0.24944*height))
        path.addCurve(to: CGPoint(x: 0.82948*width, y: 0.51868*height), control1: CGPoint(x: 0.86222*width, y: 0.44321*height), control2: CGPoint(x: 0.85027*width, y: 0.47895*height))
        path.addCurve(to: CGPoint(x: 0.74755*width, y: 0.64255*height), control1: CGPoint(x: 0.80881*width, y: 0.55819*height), control2: CGPoint(x: 0.77998*width, y: 0.60054*height))
        path.addCurve(to: CGPoint(x: 0.55076*width, y: 0.86102*height), control1: CGPoint(x: 0.68271*width, y: 0.72656*height), control2: CGPoint(x: 0.60437*width, y: 0.80807*height))
        path.addCurve(to: CGPoint(x: 0.45181*width, y: 0.86102*height), control1: CGPoint(x: 0.5246*width, y: 0.88686*height), control2: CGPoint(x: 0.47797*width, y: 0.88686*height))
        path.addCurve(to: CGPoint(x: 0.255*width, y: 0.64255*height), control1: CGPoint(x: 0.3982*width, y: 0.80807*height), control2: CGPoint(x: 0.31985*width, y: 0.72656*height))
        path.addCurve(to: CGPoint(x: 0.17307*width, y: 0.51868*height), control1: CGPoint(x: 0.22258*width, y: 0.60054*height), control2: CGPoint(x: 0.19375*width, y: 0.55819*height))
        path.addCurve(to: CGPoint(x: 0.14035*width, y: 0.4141*height), control1: CGPoint(x: 0.15228*width, y: 0.47895*height), control2: CGPoint(x: 0.14035*width, y: 0.44321*height))
        path.addCurve(to: CGPoint(x: 0.50128*width, y: 0.11594*height), control1: CGPoint(x: 0.14035*width, y: 0.24944*height), control2: CGPoint(x: 0.30195*width, y: 0.11594*height))
        path.closeSubpath()
        return path
    }
}


#Preview {
    PointerBulb(color: .blue)
}
