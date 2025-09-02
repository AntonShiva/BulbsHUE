//
//  RoomColorStateService.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 2.09.2025.
//

import SwiftUI
import Combine

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
    
    // MARK: - Singleton
    
    static let shared = RoomColorStateService()
    
    private init() {
        // Приватный инициализатор для Singleton
    }
    
    // MARK: - Public Methods
    
    /// Установить цвет для комнаты
    /// - Parameters:
    ///   - roomId: ID комнаты
    ///   - color: Цвет для установки
    func setRoomColor(_ roomId: String, color: Color) {
        roomColors[roomId] = color
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
    }
    
    /// Очистить все состояния
    func clearAllStates() {
        roomColors.removeAll()
    }
}
