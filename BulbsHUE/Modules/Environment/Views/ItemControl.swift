//
//  LampItemControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import SwiftUI

struct ItemControl: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    // Конкретная лампа, которой управляет этот контрол
    let light: Light
    
    // Локальные состояния, синхронизируемые с моделью
    @State private var isOn: Bool
    @State private var percent: Double
    @State private var debouncedTask: Task<Void, Never>?
    @State private var lastSentPercent: Double = -1
    
    // Цвет по умолчанию — тёплый нейтрально-желтоватый (примерно 2700–3000K)
    private let defaultWarmColor = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)

    init(light: Light) {
        self.light = light
        _isOn = State(initialValue: light.on.on)
        _percent = State(initialValue: light.dimming?.brightness ?? 100)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Метки с комнатой, именем и статусом питания
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isOn ? Color.green.opacity(0.9) : Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text(isOn ? "ON" : "OFF")
                        .font(Font.custom("DMSans-Medium", size: 11))
                        .foregroundStyle(isOn ? Color.green.opacity(0.9) : Color.gray.opacity(0.8))
                        .textCase(.uppercase)
                }
                Text(roomName)
                    .font(Font.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text(light.metadata.name)
                    .font(Font.custom("DMSans-Medium", size: 14))
                    .foregroundStyle(Color.white)
            }
            .adaptiveOffset(x: 4, y: -8)

            // Основной контрол и слайдер
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
        .onReceive(appViewModel.lightsViewModel.$lights) { updated in
            // Синхронизируем локальное состояние при обновлении модели
            if let updatedLight = updated.first(where: { $0.id == light.id }) {
                isOn = updatedLight.on.on
                percent = updatedLight.dimming?.brightness ?? percent
            }
        }
    }

    private var roomName: String {
        // Маппинг: в проекте используется archetype для хранения roomId
        if let roomId = light.metadata.archetype,
           let group = appViewModel.groupsViewModel.groups.first(where: { $0.id == roomId }) {
            return group.metadata?.name ?? "Без комнаты"
        }
        return "Без комнаты"
    }

    // MARK: - Networking hooks
    @MainActor
    private func sendBrightnessThrottled(_ v: Double) async {
        if let target = appViewModel.lightsViewModel.lights.first(where: { $0.id == light.id }) {
            appViewModel.lightsViewModel.setBrightness(for: target, brightness: v)
        }
        lastSentPercent = v
    }
    
    @MainActor
    private func sendBrightnessCommit(_ v: Double) async {
        if let target = appViewModel.lightsViewModel.lights.first(where: { $0.id == light.id }) {
            appViewModel.lightsViewModel.commitBrightness(for: target, brightness: v)
        }
        lastSentPercent = v
    }
    
    @MainActor
    private func sendPower(_ on: Bool) async {
        if let target = appViewModel.lightsViewModel.lights.first(where: { $0.id == light.id }) {
            appViewModel.lightsViewModel.setPower(for: target, on: on)
        }
    }
}

#Preview {
    let vm = AppViewModel()
    let mock = Light(
        id: "light_mock_01",
        type: "light",
        metadata: LightMetadata(name: "Hue Bulb 1", archetype: nil),
        on: OnState(on: true),
        dimming: Dimming(brightness: 42),
        color: nil,
        color_temperature: nil,
        effects: nil,
        effects_v2: nil,
        mode: nil,
        capabilities: nil,
        color_gamut_type: nil,
        color_gamut: nil,
        gradient: nil
    )
    return ItemControl(light: mock)
        .environmentObject(vm)
}
