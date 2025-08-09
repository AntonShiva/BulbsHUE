//
//  CustomSlider.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import SwiftUI
import UIKit

struct CustomSlider: View {
    // 0...100 (% яркости)
    @Binding var percent: Double
    // Базовый цвет лампы (корпус светлее, заливка/бегунок темнее)
    var color: Color

    var width: CGFloat = 64
    var height: CGFloat = 140
    var cornerRadius: CGFloat = 20

    var bodyLighten: CGFloat = 0.25
    var fillDarken: CGFloat = 0.20

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let H = geo.size.height
                let fillHeight = max(0, min(H, H * CGFloat(percent / 100)))
                let topGap = max(0, H - fillHeight)
                let dynamicTop = max(0, min(cornerRadius, cornerRadius - topGap)) // плавно скругляем верх
                let bulb = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

                ZStack(alignment: .bottom) {
                    // Фон колбы — светлее
                    bulb.fill(color.lighten(bodyLighten))

                    // Заливка — темнее, растёт снизу
                    UnevenRoundedRectangle(
                        topLeadingRadius: dynamicTop,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius,
                        topTrailingRadius: dynamicTop,
                        style: .continuous
                    )
                    .fill(color.darken(fillDarken))
                    .frame(height: fillHeight)
                }
                .compositingGroup()
                .clipShape(bulb)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let y = g.location.y.clamped(to: 0...H)
                            let frac = 1 - (y / H)
                            percent = (Double(frac) * 100).clamped(to: 0...100)
                        }
                )

                // Проценты — сверху по центру
                Text("\(Int(percent))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .shadow(radius: 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.2), radius: 20)
        .accessibilityElement()
        .accessibilityLabel("Яркость")
        .accessibilityValue("\(Int(percent)) процентов")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: percent = min(100, percent + 5)
            case .decrement: percent = max(0, percent - 5)
            default: break
            }
        }
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Color {
    // Осветление/затемнение через HSB (iOS)
    func adjusted(brightness b: CGFloat = 0, saturation s: CGFloat = 0) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, sat: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &sat, brightness: &br, alpha: &a) {
            let ns = min(max(sat + s, 0), 1)
            let nb = min(max(br + b, 0), 1)
            return Color(hue: Double(h), saturation: Double(ns), brightness: Double(nb), opacity: Double(a))
        } else {
            // Fallback: простое затемнение/осветление по RGB
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a2: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &bl, alpha: &a2)
            let k = 1 + b
            return Color(red: Double(min(max(r * k, 0), 1)),
                         green: Double(min(max(g * k, 0), 1)),
                         blue: Double(min(max(bl * k, 0), 1)),
                         opacity: Double(a2))
        }
    }
    func lighten(_ amount: CGFloat) -> Color { adjusted(brightness: amount) }
    func darken(_ amount: CGFloat) -> Color { adjusted(brightness: -amount) }
}

// MARK: - Preview (простой, без generic-обёрток)

#Preview {
    PreviewHost()
        .padding()
        .background(Color.black.opacity(0.7))
        .preferredColorScheme(.dark)
}

private struct PreviewHost: View {
    @State private var value: Double = 80
    var body: some View {
        CustomSlider(percent: $value,
                     color: Color(red: 0.55, green: 0.24, blue: 0.67))
    }
}

//@State private var sendTask: Task<Void, Never>?
//
//.onChange(of: percent) { newValue in
//    sendTask?.cancel()
//    let v = newValue
//    sendTask = Task {
//        try? await Task.sleep(nanoseconds: 150_000_000)
//        // PUT /clip/v2/resource/light/{rid} { "dimming": { "brightness": v } }
//        // или v1 /lights/{id}/state { "bri": Int(v/100*254) }
//    }
//}


