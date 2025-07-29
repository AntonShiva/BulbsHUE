//
//  Duga.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI

struct Duga: View {
    var color: Color
    var body: some View {
        DugaPath()
               .stroke(color, style: StrokeStyle(
                lineWidth: 2,
                lineCap: .round,
                lineJoin: .round
            ))
               .adaptiveFrame(width: 140, height: 56.1)
    }
}

struct DugaInvers: View {
    var color: Color

    var body: some View {
        Duga(color: color)
            .rotationEffect(.degrees(180))
    }
}


#Preview {
   ZStack {
        BG()
        
       SelectorTabEnviromentView()
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}


#Preview {
    Duga(color: .primColor)
}

struct DugaPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.99296*width, y: 0.01786*height))
        path.addLine(to: CGPoint(x: 0.19718*width, y: 0.01786*height))
        path.addCurve(to: CGPoint(x: 0.00704*width, y: 0.5*height), control1: CGPoint(x: 0.09217*width, y: 0.01786*height), control2: CGPoint(x: 0.00704*width, y: 0.23372*height))
        path.addLine(to: CGPoint(x: 0.00704*width, y: 0.5*height))
        path.addCurve(to: CGPoint(x: 0.19718*width, y: 0.98214*height), control1: CGPoint(x: 0.00704*width, y: 0.76628*height), control2: CGPoint(x: 0.09217*width, y: 0.98214*height))
        path.addLine(to: CGPoint(x: 0.99296*width, y: 0.98214*height))
        return path
    }
}

//#Preview {
//    Duga()
//        .stroke(.primColor, lineWidth: 3)
//        .adaptiveFrame(width: 140, height: 54)
//}
