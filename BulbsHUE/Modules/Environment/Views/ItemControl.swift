//
//  LampItemControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import SwiftUI

struct ItemControl: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Binding var percent: Double
    @State private var isOn: Bool = true
    @State private var debouncedTask: Task<Void, Never>?
    @State private var lastSentPercent: Double = -1
    // Цвет по умолчанию — тёплый нейтрально-желтоватый (примерно 2700–3000K)
    private let defaultWarmColor = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    var body: some View {
        ZStack {
            ControlView(isOn: $isOn,
                        baseColor: defaultWarmColor)
                .adaptiveOffset(x: -36)
            
            CustomSlider(percent: $percent,
                         color: defaultWarmColor,
                         onChange: { value in
                             // Дебаунс 150мс + коалесценция до 1%
                             debouncedTask?.cancel()
                             let v = round(value)
                             debouncedTask = Task {
                                 try? await Task.sleep(nanoseconds: 150_000_000)
                                 if Task.isCancelled { return }
                                 guard abs(v - lastSentPercent) >= 1 else { return }
                                 await sendBrightnessThrottled(v)
                             }
                         },
                         onCommit: { value in
                             debouncedTask?.cancel()
                             let v = round(value)
                             Task { await sendBrightnessCommit(v) }
                         })
            .adaptiveOffset(x: 143)
        }
        .onChange(of: isOn) { newValue in
            Task { await sendPower(newValue) }
        }
    }

    // MARK: - Networking hooks (подключим к VM/клиенту позже)
    @MainActor
    private func sendBrightnessThrottled(_ v: Double) async {
        if let light = appViewModel.lightsViewModel.selectedLight ?? appViewModel.lightsViewModel.lights.first {
            appViewModel.lightsViewModel.setBrightness(for: light, brightness: v)
        }
        lastSentPercent = v
    }
    
    @MainActor
    private func sendBrightnessCommit(_ v: Double) async {
        if let light = appViewModel.lightsViewModel.selectedLight ?? appViewModel.lightsViewModel.lights.first {
            appViewModel.lightsViewModel.commitBrightness(for: light, brightness: v)
        }
        lastSentPercent = v
    }
    
    @MainActor
    private func sendPower(_ on: Bool) async {
        if let light = appViewModel.lightsViewModel.selectedLight ?? appViewModel.lightsViewModel.lights.first {
            appViewModel.lightsViewModel.setPower(for: light, on: on)
        }
    }
}

#Preview {
    ItemControl(percent: .constant(10.5))
}
