//
//  LightColorStateService.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 1.09.2025.
//

import SwiftUI
import Combine

// MARK: - Light Color State Management

/// Сервис для управления состоянием цвета ламп
/// Отвечает за сохранение и восстановление цветового состояния ламп
/// Следует принципам SOLID - Single Responsibility
@MainActor
final class LightColorStateService: ObservableObject {
    
    // MARK: - Private Properties
    
    /// Словарь для хранения установленных цветов ламп
    /// Ключ - ID лампы, значение - цвет
    @Published private var lightColors: [String: Color] = [:]
    
    /// Словарь для хранения позиций в ColorPicker
    /// Ключ - ID лампы, значение - относительная позиция (0-1)
    @Published private var colorPickerPositions: [String: CGPoint] = [:]
    
    // MARK: - Singleton
    
    static let shared = LightColorStateService()
    
    private init() {
        // Приватный инициализатор для Singleton
    }
    
    // MARK: - Public Methods
    
    /// Установить цвет для лампы
    /// - Parameters:
    ///   - lightId: ID лампы
    ///   - color: Цвет для установки
    ///   - position: Позиция в ColorPicker (относительная 0-1)
    func setLightColor(_ lightId: String, color: Color, position: CGPoint? = nil) {
        lightColors[lightId] = color
        
        if let position = position {
            colorPickerPositions[lightId] = position
        }
        
        print("🎨 LightColorStateService: Сохранен цвет для лампы \(lightId)")
    }
    
    /// Получить цвет лампы
    /// - Parameter lightId: ID лампы
    /// - Returns: Сохраненный цвет или nil
    func getLightColor(_ lightId: String) -> Color? {
        return lightColors[lightId]
    }
    
    /// Получить позицию в ColorPicker для лампы
    /// - Parameter lightId: ID лампы
    /// - Returns: Сохраненная позиция или nil
    func getColorPickerPosition(_ lightId: String) -> CGPoint? {
        return colorPickerPositions[lightId]
    }
    
    /// Получить baseColor для лампы (для отображения в ItemControl)
    /// - Parameter light: Лампа
    /// - Returns: Цвет для отображения в ItemControl
    func getBaseColor(for light: Light) -> Color {
        // Проверяем, есть ли установленный пользователем цвет
        if let customColor = lightColors[light.id] {
            return customColor
        }
        
        // Пытаемся получить цвет из API данных лампы
        if let colorState = light.color,
           let xyColor = colorState.xy {
            
            // Конвертируем XY в RGB
            let (r, g, b) = convertXYToRGB(x: Double(xyColor.x), y: Double(xyColor.y))
            return Color(red: r, green: g, blue: b)
        }
        
        // Если нет данных о цвете - возвращаем дефолтный теплый цвет
        return Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    }
    
    /// Очистить состояние для лампы
    /// - Parameter lightId: ID лампы
    func clearLightState(_ lightId: String) {
        lightColors.removeValue(forKey: lightId)
        colorPickerPositions.removeValue(forKey: lightId)
    }
    
    /// Очистить все состояния
    func clearAllStates() {
        lightColors.removeAll()
        colorPickerPositions.removeAll()
    }
    
    // MARK: - Helper Methods
    
    /// Конвертирует XY координаты в RGB
    /// Приближенная конверсия для отображения
    private func convertXYToRGB(x: Double, y: Double) -> (red: Double, green: Double, blue: Double) {
        // Простая конверсия из XY в RGB для отображения
        // В реальном приложении следует использовать более точную конверсию с учетом цветового треугольника
        
        let z = 1.0 - x - y
        
        // Нормализуем в RGB
        let X = x / y
        let Y = 1.0
        let Z = z / y
        
        // sRGB conversion matrix (приближенная)
        let r = X * 3.2406 + Y * (-1.5372) + Z * (-0.4986)
        let g = X * (-0.9689) + Y * 1.8758 + Z * 0.0415
        let b = X * 0.0557 + Y * (-0.2040) + Z * 1.0570
        
        // Gamma correction и нормализация
        func gammaCorrect(_ component: Double) -> Double {
            let linear = max(0, min(1, component))
            return linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1.0/2.4) - 0.055
        }
        
        return (
            red: gammaCorrect(r),
            green: gammaCorrect(g),
            blue: gammaCorrect(b)
        )
    }
}

// MARK: - Extensions for Color Analysis

extension Color {
    /// Получить относительную позицию цвета в цветовом круге
    /// - Parameter imageSize: Размер изображения цветового круга
    /// - Returns: Относительная позиция (0-1)
    func getColorPickerPosition(imageSize: CGSize = CGSize(width: 320, height: 320)) -> CGPoint {
        // Получаем HSB компоненты цвета
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return CGPoint(x: 0.5, y: 0.5) // Центр по умолчанию
        }
        
        // Конвертируем HSB в полярные координаты
        let angle = Double(hue) * 2 * .pi - .pi // Приводим к -π...π
        let radius = Double(saturation) * (imageSize.width / 2)
        
        // Конвертируем в декартовы координаты
        let x = radius * cos(angle)
        let y = radius * sin(angle)
        
        // Приводим к относительным координатам (0-1)
        let relativeX = (x / imageSize.width) + 0.5
        let relativeY = (y / imageSize.height) + 0.5
        
        return CGPoint(
            x: max(0, min(1, relativeX)),
            y: max(0, min(1, relativeY))
        )
        #else
        return CGPoint(x: 0.5, y: 0.5)
        #endif
    }
}
