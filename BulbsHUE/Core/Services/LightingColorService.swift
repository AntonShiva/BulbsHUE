//
//  LightingColorService.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import SwiftUI
import Foundation

// MARK: - Реализация сервиса управления цветом освещения

/// Сервис для управления цветом и яркостью ламп и комнат
/// Реализует протоколы ColorManaging и BrightnessManaging
/// Следует принципу Single Responsibility - отвечает только за управление освещением
@MainActor
class LightingColorService: LightingManaging {
    
    // MARK: - Dependencies
    
    /// Сервис управления лампами
    private let lightControlService: LightControlService?
    
    /// AppViewModel для доступа к данным ламп и комнат
    private weak var appViewModel: AppViewModel?
    
    // MARK: - Initialization
    
    /// Инициализация с внедрением зависимостей
    /// Следует принципу Dependency Inversion - зависит от абстракций
    init(lightControlService: LightControlService?, appViewModel: AppViewModel?) {
        self.lightControlService = lightControlService
        self.appViewModel = appViewModel
    }
    
    // MARK: - ColorManaging Implementation
    
    /// Установить цвет для конкретной лампы
    func setColor(for light: Light, color: Color) async throws {
        guard let lightControlService = lightControlService else {
            throw LightingError.serviceNotAvailable
        }
        
        // Конвертируем SwiftUI Color в RGB компоненты
        let rgbComponents = color.rgbComponents
        
        // Выполняем изменение цвета через LightControlService
        try await lightControlService.setLightColor(
            lightId: light.id,
            red: rgbComponents.red,
            green: rgbComponents.green,
            blue: rgbComponents.blue
        )
        
        print("✅ Цвет лампы '\(light.metadata.name)' изменен на RGB(\(rgbComponents.red), \(rgbComponents.green), \(rgbComponents.blue))")
    }
    
    /// Установить цвет для всех ламп в комнате
    func setColor(for room: RoomEntity, color: Color) async throws {
        guard let appViewModel = appViewModel else {
            throw LightingError.dataNotAvailable
        }
        
        // Получаем все лампы комнаты
        let roomLights = appViewModel.lightsViewModel.lights.filter { light in
            room.lightIds.contains(light.id)
        }
        
        guard !roomLights.isEmpty else {
            throw LightingError.noLightsInRoom
        }
        
        print("🏠 Изменяем цвет для \(roomLights.count) ламп в комнате '\(room.name)'")
        
        // Применяем цвет ко всем лампам в комнате параллельно
        try await withThrowingTaskGroup(of: Void.self) { group in
            for light in roomLights {
                group.addTask {
                    try await self.setColor(for: light, color: color)
                }
            }
            
            // Ждем завершения всех операций
            for try await _ in group {
                // Процессируем каждый результат
            }
        }
        
        print("✅ Цвет всех ламп в комнате '\(room.name)' успешно изменен")
    }
    
    /// Получить текущий цвет лампы
    func getCurrentColor(for light: Light) -> Color {
        // Возвращаем цвет на основе текущих RGB компонентов лампы
        if let colorState = light.color,
           let xyColor = colorState.xy {
            return Color(
                red: Double(xyColor.x),
                green: Double(xyColor.y),
                blue: 1.0 - Double(xyColor.x) - Double(xyColor.y)
            )
        }
        
        // Возвращаем теплый белый как базовый цвет
        return Color(red: 1.0, green: 0.8, blue: 0.6)
    }
    
    /// Получить средний цвет ламп в комнате
    func getAverageColor(for room: RoomEntity) -> Color {
        guard let appViewModel = appViewModel else {
            return Color.white
        }
        
        let roomLights = appViewModel.lightsViewModel.lights.filter { light in
            room.lightIds.contains(light.id)
        }
        
        guard !roomLights.isEmpty else {
            return Color.white
        }
        
        // Вычисляем средний цвет всех ламп
        let totalRed = roomLights.reduce(0.0) { sum, light in
            sum + getCurrentColor(for: light).rgbComponents.red
        }
        let totalGreen = roomLights.reduce(0.0) { sum, light in
            sum + getCurrentColor(for: light).rgbComponents.green
        }
        let totalBlue = roomLights.reduce(0.0) { sum, light in
            sum + getCurrentColor(for: light).rgbComponents.blue
        }
        
        let count = Double(roomLights.count)
        return Color(
            red: totalRed / count,
            green: totalGreen / count,
            blue: totalBlue / count
        )
    }
    
    // MARK: - BrightnessManaging Implementation
    
    /// Установить яркость для конкретной лампы
    func setBrightness(for light: Light, brightness: Double) async throws {
        guard let lightControlService = lightControlService else {
            throw LightingError.serviceNotAvailable
        }
        
        // Проверяем диапазон яркости
        let clampedBrightness = max(0.0, min(100.0, brightness))
        
        try await lightControlService.setLightBrightness(
            lightId: light.id,
            brightness: clampedBrightness
        )
        
        print("✅ Яркость лампы '\(light.metadata.name)' изменена на \(clampedBrightness)%")
    }
    
    /// Установить яркость для всех ламп в комнате
    func setBrightness(for room: RoomEntity, brightness: Double) async throws {
        guard let appViewModel = appViewModel else {
            throw LightingError.dataNotAvailable
        }
        
        let roomLights = appViewModel.lightsViewModel.lights.filter { light in
            room.lightIds.contains(light.id)
        }
        
        guard !roomLights.isEmpty else {
            throw LightingError.noLightsInRoom
        }
        
        print("🏠 Изменяем яркость для \(roomLights.count) ламп в комнате '\(room.name)'")
        
        // Применяем яркость ко всем лампам в комнате параллельно
        try await withThrowingTaskGroup(of: Void.self) { group in
            for light in roomLights {
                group.addTask {
                    try await self.setBrightness(for: light, brightness: brightness)
                }
            }
            
            for try await _ in group {
                // Процессируем каждый результат
            }
        }
        
        print("✅ Яркость всех ламп в комнате '\(room.name)' успешно изменена на \(brightness)%")
    }
}

// MARK: - Ошибки сервиса

/// Ошибки управления освещением
enum LightingError: Error, LocalizedError {
    case serviceNotAvailable
    case dataNotAvailable
    case noLightsInRoom
    case invalidColorValue
    case invalidBrightnessValue
    
    var errorDescription: String? {
        switch self {
        case .serviceNotAvailable:
            return "Сервис управления лампами недоступен"
        case .dataNotAvailable:
            return "Данные приложения недоступны"
        case .noLightsInRoom:
            return "В комнате нет ламп"
        case .invalidColorValue:
            return "Некорректное значение цвета"
        case .invalidBrightnessValue:
            return "Некорректное значение яркости (должно быть 0-100)"
        }
    }
}

// MARK: - Extensions для работы с цветом

extension Color {
    /// Получить RGB компоненты цвета
    var rgbComponents: (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
        #else
        // Fallback для macOS
        let nsColor = NSColor(self)
        let converted = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        return (Double(converted.redComponent), Double(converted.greenComponent), Double(converted.blueComponent))
        #endif
    }
}
