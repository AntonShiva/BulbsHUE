//
//  ColorConversion.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import Foundation
import SwiftUI
import CoreGraphics

/// Утилита для конвертации цветов между различными цветовыми пространствами
struct ColorConversion {
    
    /// Конвертирует SwiftUI Color в XY координаты с учетом гаммы лампы
    /// - Parameters:
    ///   - color: Цвет SwiftUI
    ///   - gamutType: Тип цветовой гаммы (A, B, C или nil)
    /// - Returns: XY координаты для Hue API
    static func convertToXY(color: SwiftUI.Color, gamutType: String? = nil) -> XYColor {
        // Получаем компоненты цвета
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        
        // Для SwiftUI используем UIColor/NSColor
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        #elseif canImport(AppKit)
        let nsColor = NSColor(color)
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        #endif
        
        // Применяем гамма-коррекцию (sRGB -> линейный RGB)
        red = gammaCorrection(red)
        green = gammaCorrection(green)
        blue = gammaCorrection(blue)
        
        // Конвертируем в XYZ используя Wide RGB D65
        let X = red * 0.4124 + green * 0.3576 + blue * 0.1805
        let Y = red * 0.2126 + green * 0.7152 + blue * 0.0722
        let Z = red * 0.0193 + green * 0.1192 + blue * 0.9505
        
        // Конвертируем в xy
        let sum = X + Y + Z
        var x = sum > 0 ? X / sum : 0
        var y = sum > 0 ? Y / sum : 0
        
        // Проверяем и корректируем для гаммы лампы
        let xyPoint = XYColor(x: x, y: y)
        let gamut = getGamutForType(gamutType)
        
        if !isPointInGamut(xyPoint, gamut: gamut) {
            let corrected = closestPointInGamut(xyPoint, gamut: gamut)
            x = corrected.x
            y = corrected.y
        }
        
        return XYColor(x: x, y: y)
    }
    
    /// Конвертирует XY в RGB (для отображения в UI)
    static func convertXYToColor(_ xy: XYColor, brightness: Double = 1.0, gamutType: String? = nil) -> Color {
        let gamut = getGamutForType(gamutType)
        var xyPoint = xy
        
        // Проверяем и корректируем точку в пределах гаммы
        if !isPointInGamut(xyPoint, gamut: gamut) {
            xyPoint = closestPointInGamut(xyPoint, gamut: gamut)
        }
        
        // Конвертируем xy в XYZ
        let z = 1.0 - xyPoint.x - xyPoint.y
        let Y = brightness
        let X = (Y / xyPoint.y) * xyPoint.x
        let Z = (Y / xyPoint.y) * z
        
        // Конвертируем XYZ в RGB (sRGB D65)
        var r = X * 1.656492 - Y * 0.354851 - Z * 0.255038
        var g = -X * 0.707196 + Y * 1.655397 + Z * 0.036152
        var b = X * 0.051713 - Y * 0.121364 + Z * 1.011530
        
        // Ограничиваем значения если они выходят за пределы
        if r > b && r > g && r > 1.0 {
            g = g / r
            b = b / r
            r = 1.0
        } else if g > b && g > r && g > 1.0 {
            r = r / g
            b = b / g
            g = 1.0
        } else if b > r && b > g && b > 1.0 {
            r = r / b
            g = g / b
            b = 1.0
        }
        
        // Применяем обратную гамма-коррекцию (линейный RGB -> sRGB)
        r = inverseGammaCorrection(r)
        g = inverseGammaCorrection(g)
        b = inverseGammaCorrection(b)
        
        // Финальная проверка диапазона
        r = max(0, min(1, r))
        g = max(0, min(1, g))
        b = max(0, min(1, b))
        
        return Color(red: r, green: g, blue: b)
    }
    
    /// Конвертирует температуру в Кельвинах в mired
    static func kelvinToMired(_ kelvin: Int) -> Int {
        return 1_000_000 / kelvin
    }
    
    /// Конвертирует mired в температуру в Кельвинах
    static func miredToKelvin(_ mired: Int) -> Int {
        return 1_000_000 / mired
    }
    
    // MARK: - Private Methods
    
    /// Применяет гамма-коррекцию
    private static func gammaCorrection(_ value: CGFloat) -> CGFloat {
        return value > 0.04045 ? pow((value + 0.055) / 1.055, 2.4) : (value / 12.92)
    }
    
    /// Применяет обратную гамма-коррекцию
    private static func inverseGammaCorrection(_ value: CGFloat) -> CGFloat {
        return value <= 0.0031308 ? 12.92 * value : (1.0 + 0.055) * pow(value, (1.0 / 2.4)) - 0.055
    }
    
    /// Получает треугольник гаммы для типа
    private static func getGamutForType(_ type: String?) -> Gamut {
        switch type {
        case "A":
            // Legacy LivingColors (Bloom, Aura, Light Strips, Iris)
            return Gamut(
                red: XYColor(x: 0.704, y: 0.296),
                green: XYColor(x: 0.2151, y: 0.7106),
                blue: XYColor(x: 0.138, y: 0.08)
            )
        case "B":
            // Старые Hue bulbs
            return Gamut(
                red: XYColor(x: 0.675, y: 0.322),
                green: XYColor(x: 0.409, y: 0.518),
                blue: XYColor(x: 0.167, y: 0.04)
            )
        case "C":
            // Новые Hue bulbs
            return Gamut(
                red: XYColor(x: 0.6915, y: 0.3038),
                green: XYColor(x: 0.17, y: 0.7),
                blue: XYColor(x: 0.1532, y: 0.0475)
            )
        default:
            // Дефолтная гамма (полный спектр)
            return Gamut(
                red: XYColor(x: 1.0, y: 0),
                green: XYColor(x: 0.0, y: 1.0),
                blue: XYColor(x: 0.0, y: 0.0)
            )
        }
    }
    
    /// Проверяет, находится ли точка внутри треугольника гаммы
    private static func isPointInGamut(_ point: XYColor, gamut: Gamut) -> Bool {
        guard let red = gamut.red,
              let green = gamut.green,
              let blue = gamut.blue else { return true }
        
        let v1 = CGPoint(x: green.x - red.x, y: green.y - red.y)
        let v2 = CGPoint(x: blue.x - red.x, y: blue.y - red.y)
        let q = CGPoint(x: point.x - red.x, y: point.y - red.y)
        
        let s = crossProduct(q, v2) / crossProduct(v1, v2)
        let t = crossProduct(v1, q) / crossProduct(v1, v2)
        
        return (s >= 0.0) && (t >= 0.0) && (s + t <= 1.0)
    }
    
    /// Вычисляет векторное произведение
    private static func crossProduct(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return p1.x * p2.y - p1.y * p2.x
    }
    
    /// Находит ближайшую точку внутри гаммы
    private static func closestPointInGamut(_ point: XYColor, gamut: Gamut) -> XYColor {
        guard let red = gamut.red,
              let green = gamut.green,
              let blue = gamut.blue else { return point }
        
        // Находим ближайшую точку на каждой стороне треугольника
        let pRG = closestPointOnLine(
            point: point,
            lineStart: red,
            lineEnd: green
        )
        
        let pGB = closestPointOnLine(
            point: point,
            lineStart: green,
            lineEnd: blue
        )
        
        let pBR = closestPointOnLine(
            point: point,
            lineStart: blue,
            lineEnd: red
        )
        
        // Вычисляем расстояния
        let dRG = distance(from: point, to: pRG)
        let dGB = distance(from: point, to: pGB)
        let dBR = distance(from: point, to: pBR)
        
        // Возвращаем ближайшую точку
        if dRG <= dGB && dRG <= dBR {
            return pRG
        } else if dGB <= dBR {
            return pGB
        } else {
            return pBR
        }
    }
    
    /// Находит ближайшую точку на линии
    private static func closestPointOnLine(point: XYColor, lineStart: XYColor, lineEnd: XYColor) -> XYColor {
        let ap = CGPoint(x: point.x - lineStart.x, y: point.y - lineStart.y)
        let ab = CGPoint(x: lineEnd.x - lineStart.x, y: lineEnd.y - lineStart.y)
        
        let ab2 = ab.x * ab.x + ab.y * ab.y
        let ap_ab = ap.x * ab.x + ap.y * ab.y
        
        var t = ap_ab / ab2
        t = max(0.0, min(1.0, t))
        
        return XYColor(
            x: lineStart.x + ab.x * t,
            y: lineStart.y + ab.y * t
        )
    }
    
    /// Вычисляет расстояние между точками
    private static func distance(from p1: XYColor, to p2: XYColor) -> Double {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
}
