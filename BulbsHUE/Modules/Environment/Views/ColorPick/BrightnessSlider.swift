//
//  BrightnessSlider.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/30/25.
//

import SwiftUI
import Combine

/// Переиспользуемый компонент слайдера яркости
struct BrightnessSlider: View {
    @Binding var brightness: Double
    let color: Color
    
    
    init(brightness: Binding<Double>, color: Color = .white, title: String = "BRIGHTNESS, %") {
        self._brightness = brightness
        self.color = color
       
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Заголовок слайдера
            Text("BRIGHTNESS \(Int(brightness))%")
                .font(Font.custom("DMSans-ExtraLight", size: 12))
                .kerning(2.04)
                .foregroundColor(.white)
                .textCase(.uppercase)
            
            // Контейнер слайдера
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Фон слайдера
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 312, height: 56)
                        .cornerRadius(12)
                    
                    // Активная часть слайдера (заполнение)
                    Rectangle()
                        .fill(color)
                        .frame(width: min(312 * CGFloat(brightness / 100), 312), height: 56)
                        .cornerRadius(12)
                        .animation(.easeInOut(duration: 0.2), value: brightness)
                    
                    // Текст с процентами
                    HStack {
                        Spacer()
                        Text("\(Int(brightness))%")
                            .font(Font.custom("DMSans-ExtraLight", size: 12))
                            .kerning(2.04)
                            .foregroundColor(.white)
                            .textCase(.uppercase)
                            .padding(.trailing, 24)
                    }
                }
                .onTapGesture { tapLocation in
                    // Обработка тапа для изменения яркости
                    let newBrightness = min(max((tapLocation.x / 312) * 100, 0), 100)
                    brightness = newBrightness
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Обработка перетаскивания для изменения яркости
                            let newBrightness = min(max((value.location.x / 312) * 100, 0), 100)
                            brightness = newBrightness
                        }
                )
            }
            .frame(width: 312, height: 56)
        }
    }
}

/// Множественные слайдеры яркости для разных ламп
struct MultipleBrightnessSliders: View {
    @StateObject private var viewModel = MultipleBrightnessSlidersViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.lamps.indices, id: \.self) { index in
                BrightnessSlider(
                    brightness: $viewModel.lamps[index].brightness,
                    color: viewModel.lamps[index].color
                )
            }
        }
    }
}

// MARK: - ViewModel для множественных слайдеров

@MainActor
class MultipleBrightnessSlidersViewModel: ObservableObject {
    @Published var lamps: [LampBrightnessData] = []
    
    init() {
        setupLamps()
    }
    
    private func setupLamps() {
        lamps = [
            LampBrightnessData(
                id: "lamp1",
                brightness: 24.0,
                color: Color(red: 0.976, green: 0.451, blue: 0.188) // Оранжевый
            ),
            LampBrightnessData(
                id: "lamp2", 
                brightness: 56.0,
                color: Color(red: 0.984, green: 0.792, blue: 0.475) // Желтоватый
            ),
            LampBrightnessData(
                id: "lamp3",
                brightness: 78.0,
                color: Color(red: 0.984, green: 0.941, blue: 0.541) // Желтый
            )
        ]
    }
}

// MARK: - Модель данных для лампы

struct LampBrightnessData: Identifiable {
    let id: String
    var brightness: Double
    let color: Color
}

// MARK: - Preview

#Preview("Single Brightness Slider") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            BrightnessSlider(
                brightness: .constant(45),
                color: .white,
                title: "BRIGHTNESS, %"
            )
        }
        .padding()
    }
}

#Preview("Multiple Brightness Sliders") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            MultipleBrightnessSliders()
        }
        .padding()
    }
}
