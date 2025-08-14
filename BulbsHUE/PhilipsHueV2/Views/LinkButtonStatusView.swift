//
//  LinkButtonStatusView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/14/25.


// Файл: BulbsHUE/PhilipsHueV2/Views/LinkButtonStatusView.swift
// ИСПРАВЛЕННЫЙ компонент для правильной обработки нажатия кнопки Link

import SwiftUI

/// Визуальный индикатор процесса подключения к Hue Bridge
struct LinkButtonStatusView: View {
    let isConnecting: Bool
    let linkButtonPressed: Bool
    let connectionAttempts: Int
    let maxAttempts: Int = 30
    let error: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Визуальный индикатор
            ZStack {
                // Фоновый круг прогресса
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                // Прогресс подключения
                if isConnecting && !linkButtonPressed {
                    Circle()
                        .trim(from: 0, to: CGFloat(connectionAttempts) / CGFloat(maxAttempts))
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 2), value: connectionAttempts)
                }
                
                // Центральная иконка
                if linkButtonPressed {
                    // Успех
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if error != nil {
                    // Ошибка
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                        .transition(.scale.combined(with: .opacity))
                } else if isConnecting {
                    // Процесс подключения
                    VStack(spacing: 4) {
                        Image(systemName: "hand.point.up.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.cyan)
                            .symbolEffect(.pulse, value: isConnecting)
                        
                        Text("\(connectionAttempts)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                } else {
                    // Ожидание начала
                    Image(systemName: "wifi.router")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .animation(.spring(), value: linkButtonPressed)
            .animation(.easeInOut, value: error)
            
            // Текстовые статусы
            VStack(spacing: 8) {
                if linkButtonPressed {
                    StatusText(
                        icon: "checkmark.circle",
                        text: "Подключено успешно",
                        color: .green
                    )
                } else if error != nil {
                    StatusText(
                        icon: "xmark.circle",
                        text: "Ошибка подключения",
                        color: .red
                    )
                } else if isConnecting {
                    StatusText(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Попытка \(connectionAttempts) из \(maxAttempts)",
                        color: .cyan
                    )
                } else {
                    StatusText(
                        icon: "info.circle",
                        text: "Готов к подключению",
                        color: .white.opacity(0.6)
                    )
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
    }
}

/// Компонент для отображения статусного текста
private struct StatusText: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
    }
}

/// Анимированная кнопка Link на изображении моста
struct AnimatedLinkButton: View {
    @State private var isAnimating = false
    let isActive: Bool
    let isPressed: Bool
    
    var body: some View {
        ZStack {
            // Пульсирующие круги когда активно
            if isActive && !isPressed {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.cyan.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                        .frame(width: 50 + CGFloat(index * 20), height: 50 + CGFloat(index * 20))
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            Animation.easeOut(duration: 2.0)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.4),
                            value: isAnimating
                        )
                }
            }
            
            // Основная кнопка
            Circle()
                .fill(buttonColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Иконка состояния
            if isPressed {
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .bold))
            } else if isActive {
                Image(systemName: "hand.point.up.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                    .symbolEffect(.pulse, value: isActive)
            }
        }
        .onAppear {
            if isActive && !isPressed {
                isAnimating = true
            }
        }
        .onChange(of: isActive) { newValue in
            isAnimating = newValue && !isPressed
        }
    }
    
    private var buttonColor: Color {
        if isPressed {
            return .green
        } else if isActive {
            return .cyan
        } else {
            return .gray
        }
    }
}

/// Детальная инструкция для пользователя
struct LinkButtonInstructionView: View {
    let isWaiting: Bool
    let attemptsCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            if isWaiting {
                Text("Нажмите кнопку Link")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Нажмите круглую кнопку на верхней части Hue Bridge")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                // Визуальная подсказка
                HStack(spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.cyan)
                    Text("Найдите круглую кнопку на мосту")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.cyan)
                    Text("Нажмите кнопку один раз")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.cyan)
                    Text("Дождитесь подтверждения")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
