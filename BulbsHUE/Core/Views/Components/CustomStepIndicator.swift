//
//  CustomStepIndicator.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 18.08.2025.
//

import SwiftUI

struct CustomStepIndicator: View {
    /// Текущий шаг: 0, 1, 2
    let currentStep: Int
    
    // Конфигурация для каждого состояния
    private var configurations: [StepConfiguration] {
        [
            // Состояние 0: прямоугольник слева, две точки справа
            StepConfiguration(
                rectangleOffset: -16,
                circleOffsets: [12, 28]
            ),
            // Состояние 1: точка слева, прямоугольник по центру, точка справа
            StepConfiguration(
                rectangleOffset: 0,
                circleOffsets: [-28, 28]
            ),
            // Состояние 2: две точки слева, прямоугольник справа
            StepConfiguration(
                rectangleOffset: 16,
                circleOffsets: [-28, -12]
            )
        ]
    }
    
    private var currentConfig: StepConfiguration {
        let safeIndex = max(0, min(currentStep, configurations.count - 1))
        return configurations[safeIndex]
    }
    
    var body: some View {
        ZStack {
            // Прямоугольник (активная область)
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 32, height: 8)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(100)
                .offset(x: currentConfig.rectangleOffset, y: 0)
            
            // Точки (неактивные области)
            ForEach(Array(currentConfig.circleOffsets.enumerated()), id: \.offset) { index, xOffset in
                Circle()
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .frame(width: 8, height: 8)
                    .offset(x: xOffset, y: 0)
                    .opacity(0.2)
            }
        }
        .frame(width: 64, height: 8)
    }
}

// MARK: - Конфигурация состояния
private struct StepConfiguration {
    let rectangleOffset: CGFloat
    let circleOffsets: [CGFloat]
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Text("Шаг 1")
        CustomStepIndicator(currentStep: 0)
        
        Text("Шаг 2")
        CustomStepIndicator(currentStep: 1)
        
        Text("Шаг 3")
        CustomStepIndicator(currentStep: 2)
    }
    .padding()
}
