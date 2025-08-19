//
//  CustomSlider.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CustomSlider: View {
    @Binding var percent: Double
    var color: Color
    // Колбэки для троттлинга/коммита
    var onChange: ((Double) -> Void)? = nil
    var onCommit: ((Double) -> Void)? = nil

    // Дизайн-габариты (будут масштабироваться через adaptiveFrame)
    var width: CGFloat = 64
    var height: CGFloat = 140
    var cornerRadius: CGFloat = 20

    // Осветление корпуса / затемнение заливки
    var bodyLighten: CGFloat = 0.25
    var fillDarken: CGFloat = 0.20

    var body: some View {
        GeometryReader { geo in
            // Фактические размеры после adaptiveFrame
            let W = geo.size.width
            let H = geo.size.height

            // Масштаб для радиусов относительно дизайн-габаритов
            let scaleX = W / width
            let scaleY = H / height
            let scale = min(scaleX, scaleY)
            let scaledCorner = cornerRadius * scale

            // Высота заливки (снизу), лёгкое floor — чтобы на 100% не «вылазило»
            let clamped = CGFloat(min(max(percent, 0), 100))
            let fillHeight = floor(H * clamped / 100)

            // Плавное скругление верха заливки, когда подбираемся к потолку
            let topGap = max(0, H - fillHeight)
            let dynamicTop = max(0, scaledCorner - topGap)

            let bulb = RoundedRectangle(cornerRadius: scaledCorner, style: .continuous)

            ZStack {
                // Колба + заливка
                ZStack(alignment: .bottom) {
                    // Фон колбы — светлее
                    bulb.fill(color.lighten(bodyLighten))

                    // Заливка — темнее, растёт снизу
                    UnevenRoundedRectangle(
                        topLeadingRadius: dynamicTop,
                        bottomLeadingRadius: scaledCorner,
                        bottomTrailingRadius: scaledCorner,
                        topTrailingRadius: dynamicTop,
                        style: .continuous
                    )
                    .fill(color.darken(fillDarken))
                    // ВАЖНО: фиксируем заливку к низу обычными frame, без adaptiveFrame
                    .frame(height: fillHeight, alignment: .bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .compositingGroup()
                .clipShape(bulb)            // ничего не выйдет за пределы колбы
                .contentShape(Rectangle())  // вся область — зона жестов
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let y = g.location.y.clamped(to: 0...H)
                            let frac = 1 - (y / H)
                            percent = (Double(frac) * 100).clamped(to: 0...100)
                            onChange?(percent)
                        }
                        .onEnded { _ in
                            onCommit?(percent)
                        }
                )

                // Проценты — поверх
                Text("\(Int(percent))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color.preferredForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .shadow(radius: 1)
                    .allowsHitTesting(false)
            }
        }
        // Внешние габариты — адаптивно (твои расширения)
        .adaptiveFrame(width: width, height: height)
        .shadow(color: .black.opacity(0.2), radius: 20)
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Color {
    // Осветление/затемнение через HSB
    func adjusted(brightness b: CGFloat = 0, saturation s: CGFloat = 0) -> Color {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var h: CGFloat = 0, sat: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &sat, brightness: &br, alpha: &a) {
            let ns = min(max(sat + s, 0), 1)
            let nb = min(max(br + b, 0), 1)
            return Color(hue: Double(h), saturation: Double(ns), brightness: Double(nb), opacity: Double(a))
        }
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a2: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &bl, alpha: &a2)
        let k = 1 + b
        return Color(red: Double(min(max(r * k, 0), 1)),
                     green: Double(min(max(g * k, 0), 1)),
                     blue: Double(min(max(bl * k, 0), 1)),
                     opacity: Double(a2))
        #else
        return self
        #endif
    }
    func lighten(_ amount: CGFloat) -> Color { adjusted(brightness: amount) }
    func darken(_ amount: CGFloat) -> Color { adjusted(brightness: -amount) }
}



// MARK: - Preview (простой, без generic-обёрток)

#Preview {
    PreviewHost()
        .padding()
        .background(Color.black.opacity(0.3))
       
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

// MARK: -- пример тролинга по сети
//                @State private var debouncedTask: Task<Void, Never>?
//                @State private var lastSentPercent: Double = -1
//
//                let hue = HueBridgeClient(bridgeIP: "192.168.0.103",
//                                          appKeyV2: "…", usernameV1: "…")
//                let lighRid = "…" // v2 RID конкретной лампы
//
//                var body: some View {
//                    CustomSlider(percent: $brightness,
//                                 color: Color(red: 0.55, green: 0.24, blue: 0.67),
//                                 onChange: { value in
//                                     // Дебаунс 150 мс
//                                     debouncedTask?.cancel()
//                                     let v = round(value) // коалесируем до целых %
//                                     debouncedTask = Task {
//                                         try? await Task.sleep(nanoseconds: 150_000_000)
//                                         if Task.isCancelled { return }
//                                         // Не шлём, если разница < 1%
//                                         guard abs(v - lastSentPercent) >= 1 else { return }
//                                         do {
//                                             try await hue.setBrightnessV2(lightRid: lightRid, percent: v)
//                                             lastSentPercent = v
//                                         } catch {
//                                         }
//                                     }
//                                 },
//                                 onCommit: { value in
//                                     // Отправляем финальное значение немедленно
//                                     debouncedTask?.cancel()
//                                     let v = round(value)
//                                     Task.detached {
//                                         do {
//                                             try await hue.setBrightnessV2(lightRid: lightRid, percent: v)
//                                         } catch {
//                                         }
//                                         await MainActor.run { lastSentPercent = v }
//                                     }
//                                 })
//                }
              // MARK: -- End
