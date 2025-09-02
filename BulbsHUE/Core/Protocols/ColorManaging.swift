//
//  ColorManaging.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import SwiftUI

// MARK: - Протокол для управления цветом ламп и комнат

/// Протокол для управления цветом освещения
/// Следует принципу Interface Segregation - содержит только методы для управления цветом
protocol ColorManaging {
    /// Установить цвет для конкретной лампы
    /// - Parameters:
    ///   - light: Целевая лампа
    ///   - color: Новый цвет
    func setColor(for light: Light, color: Color) async throws
    
    /// Установить цвет для конкретной лампы немедленно (без debouncing)
    /// - Parameters:
    ///   - light: Целевая лампа  
    ///   - color: Новый цвет
    func setColorImmediate(for light: Light, color: Color) async throws
    
    /// Установить цвет для всех ламп в комнате
    /// - Parameters:
    ///   - room: Целевая комната
    ///   - color: Новый цвет
    func setColor(for room: RoomEntity, color: Color) async throws
    
    /// Получить текущий цвет лампы
    /// - Parameter light: Целевая лампа
    /// - Returns: Текущий цвет лампы
    func getCurrentColor(for light: Light) -> Color
    
    /// Получить средний цвет ламп в комнате
    /// - Parameter room: Целевая комната
    /// - Returns: Средний цвет ламп в комнате
    func getAverageColor(for room: RoomEntity) -> Color
}

// MARK: - Протокол для управления яркостью

/// Протокол для управления яркостью освещения
/// Отделен от ColorManaging согласно принципу Interface Segregation
protocol BrightnessManaging {
    /// Установить яркость для конкретной лампы
    /// - Parameters:
    ///   - light: Целевая лампа
    ///   - brightness: Новая яркость (0.0 - 100.0)
    func setBrightness(for light: Light, brightness: Double) async throws
    
    /// Установить яркость для всех ламп в комнате
    /// - Parameters:
    ///   - room: Целевая комната
    ///   - brightness: Новая яркость (0.0 - 100.0)
    func setBrightness(for room: RoomEntity, brightness: Double) async throws
}

// MARK: - Объединенный протокол для полного управления освещением

/// Композиция протоколов для полного управления освещением
/// Следует принципу Interface Segregation - клиенты могут использовать только нужные части
typealias LightingManaging = ColorManaging & BrightnessManaging

// MARK: - Вспомогательные типы

/// Результат операции изменения цвета
struct ColorChangeResult {
    let success: Bool
    let affectedLights: [Light]
    let error: Error?
}
