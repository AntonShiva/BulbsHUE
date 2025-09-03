//
//  RoomColorStateService.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 2.09.2025.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Room Color State Management

/// Сервис для управления состоянием цвета комнат
/// Отвечает за сохранение и восстановление цветового состояния комнат
/// Следует принципам SOLID - Single Responsibility
@MainActor
final class RoomColorStateService: ObservableObject {
    
    // MARK: - Private Properties
    
    /// Словарь для хранения установленных цветов комнат
    /// Ключ - ID комнаты, значение - цвет
    @Published private var roomColors: [String: Color] = [:]
    
    /// Ключ для сохранения в UserDefaults
    private let userDefaultsKey = "RoomColorsState"
    
    // MARK: - Singleton
    
    static let shared = RoomColorStateService()
    
    private init() {
        // Приватный инициализатор для Singleton
        loadPersistedColors()
    }
    
    // MARK: - Public Methods
    
    /// Установить цвет для комнаты
    /// - Parameters:
    ///   - roomId: ID комнаты
    ///   - color: Цвет для установки
    func setRoomColor(_ roomId: String, color: Color) {
        roomColors[roomId] = color
        savePersistedColors()
        print("🎨 RoomColorStateService: Сохранен цвет для комнаты \(roomId)")
    }
    
    /// Получить цвет комнаты
    /// - Parameter roomId: ID комнаты
    /// - Returns: Сохраненный цвет или nil
    func getRoomColor(_ roomId: String) -> Color? {
        return roomColors[roomId]
    }
    
    /// Получить baseColor для комнаты (для отображения в RoomControl)
    /// - Parameter room: Комната
    /// - Returns: Цвет для отображения в RoomControl
    func getBaseColor(for room: RoomEntity) -> Color {
        // Проверяем, есть ли установленный пользователем цвет
        if let customColor = roomColors[room.id] {
            return customColor
        }
        
        // Если нет данных о цвете - возвращаем дефолтный теплый цвет
        return Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    }
    
    /// Очистить состояние для комнаты
    /// - Parameter roomId: ID комнаты
    func clearRoomState(_ roomId: String) {
        roomColors.removeValue(forKey: roomId)
        savePersistedColors()
    }
    
    /// Очистить все состояния
    func clearAllStates() {
        roomColors.removeAll()
        savePersistedColors()
    }
    
    // MARK: - Private Methods
    
    /// Загрузить сохраненные цвета из UserDefaults
    private func loadPersistedColors() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: ColorData].self, from: data) else {
            print("🎨 RoomColorStateService: Нет сохраненных цветов комнат")
            return
        }
        
        roomColors = decoded.mapValues { $0.toColor() }
        print("🎨 RoomColorStateService: Загружено \(roomColors.count) сохраненных цветов комнат")
    }
    
    /// Сохранить цвета в UserDefaults
    private func savePersistedColors() {
        let colorData = roomColors.mapValues { ColorData.fromColor($0) }
        
        if let encoded = try? JSONEncoder().encode(colorData) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("🎨 RoomColorStateService: Сохранено \(roomColors.count) цветов комнат в UserDefaults")
        } else {
            print("❌ RoomColorStateService: Ошибка сохранения цветов в UserDefaults")
        }
    }
}

// MARK: - Color Data Model

/// Модель для сериализации Color в JSON
private struct ColorData: Codable {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let alpha: Double
    
    /// Создать ColorData из SwiftUI Color
    static func fromColor(_ color: Color) -> ColorData {
        // Извлекаем компоненты цвета через UIColor
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return ColorData(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(brightness),
            alpha: Double(alpha)
        )
    }
    
    /// Преобразовать в SwiftUI Color
    func toColor() -> Color {
        return Color(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            opacity: alpha
        )
    }
}
