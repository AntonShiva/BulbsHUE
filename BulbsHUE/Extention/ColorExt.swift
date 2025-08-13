//
//  ColorExt.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI


extension ShapeStyle where Self == Color {
    static var primColor: Color {
        Color(red: 0.79, green: 1, blue: 1)
    }
//    static var accentColor: Color {
//        Color(red: 1, green: 0.3, blue: 0.3)
//    }
}

// MARK: - Контрастные цвета для текста/иконок на фоне baseColor
extension Color {
    /// Оценка воспринимаемой яркости (sRGB)
    private var perceivedLuminance: CGFloat {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        // Приводим к sRGB
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 1.0 }
        #elseif canImport(AppKit)
        let ns = NSColor(self)
        let srgb = ns.usingColorSpace(.sRGB) ?? ns
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        // По умолчанию считаем светлым, чтобы не «пропадал» текст
        let r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1
        #endif
        // Стандартная формула относительной яркости для sRGB
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Флаг «светлый фон» — белый текст будет слабо заметен
    private var isLightBackground: Bool {
        // Порог ~0.6 даёт хорошую читаемость в большинстве случаев
        perceivedLuminance > 0.6
    }

    /// Рекомендуемый цвет переднего плана (текст/иконки) на данном фоне
    var preferredForeground: Color {
        isLightBackground ? Color.black.opacity(0.8) : Color.white
    }
}
