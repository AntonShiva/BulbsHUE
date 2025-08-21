//
//  RoomDataModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/11/25.
//

import Foundation
import SwiftData

/// SwiftData модель для персистентного хранения данных комнат
/// Конвертируется в RoomEntity модель для использования в UI
@Model
final class RoomDataModel {
    
    // MARK: - Stored Properties
    
    /// Уникальный идентификатор комнаты
    var roomId: String
    
    /// Название комнаты
    var name: String
    
    /// Тип комнаты (например: LIVING_ROOM, BEDROOM, KITCHEN)
    var roomType: String
    
    /// Иконка комнаты, выбранная пользователем (например: "re1", "tr2", "pr3")
    var iconName: String
    
    /// ID ламп, назначенных в эту комнату
    var lightIds: [String]
    
    /// Активна ли комната (видна в списке)
    var isActive: Bool
    
    /// Дата создания комнаты
    var createdAt: Date
    
    /// Дата последнего обновления данных
    var updatedAt: Date
    
    // MARK: - Initialization
    
    /// Инициализация модели данных комнаты
    /// - Parameters:
    ///   - roomId: ID комнаты
    ///   - name: Название комнаты
    ///   - roomType: Тип комнаты (rawValue из RoomSubType)
    ///   - iconName: Иконка комнаты
    ///   - lightIds: Массив ID ламп
    ///   - isActive: Активна ли комната
    ///   - createdAt: Дата создания
    ///   - updatedAt: Дата обновления
    init(
        roomId: String,
        name: String,
        roomType: String,
        iconName: String,
        lightIds: [String] = [],
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.roomId = roomId
        self.name = name
        self.roomType = roomType
        self.iconName = iconName
        self.lightIds = lightIds
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - RoomEntity Conversion

extension RoomDataModel {
    
    /// Создать RoomDataModel из RoomEntity модели
    /// - Parameter roomEntity: RoomEntity модель из Domain слоя
    /// - Returns: RoomDataModel для сохранения в SwiftData
    static func fromRoomEntity(_ roomEntity: RoomEntity) -> RoomDataModel {
        return RoomDataModel(
            roomId: roomEntity.id,
            name: roomEntity.name,
            roomType: roomEntity.type.rawValue,
            iconName: roomEntity.iconName,
            lightIds: roomEntity.lightIds,
            isActive: roomEntity.isActive,
            createdAt: roomEntity.createdAt,
            updatedAt: roomEntity.updatedAt
        )
    }
    
    /// Конвертировать в RoomEntity модель для использования в UI и Domain слое
    /// - Returns: RoomEntity модель
    func toRoomEntity() -> RoomEntity {
        // Конвертируем строковый тип обратно в enum
        let roomSubType = RoomSubType(rawValue: roomType) ?? .livingRoom
        
        return RoomEntity(
            id: roomId,
            name: name,
            type: roomSubType,
            iconName: iconName,
            lightIds: lightIds,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    /// Обновить данные комнаты из RoomEntity
    /// - Parameter roomEntity: Новые данные комнаты
    func updateFromRoomEntity(_ roomEntity: RoomEntity) {
        self.name = roomEntity.name
        self.roomType = roomEntity.type.rawValue
        self.iconName = roomEntity.iconName
        self.lightIds = roomEntity.lightIds
        self.isActive = roomEntity.isActive
        self.updatedAt = Date()
    }
    
    /// Добавить лампу в комнату
    /// - Parameter lightId: ID лампы для добавления
    func addLight(_ lightId: String) {
        if !lightIds.contains(lightId) {
            lightIds.append(lightId)
            updatedAt = Date()
        }
    }
    
    /// Удалить лампу из комнаты
    /// - Parameter lightId: ID лампы для удаления
    func removeLight(_ lightId: String) {
        lightIds.removeAll { $0 == lightId }
        updatedAt = Date()
    }
}

// MARK: - Computed Properties

extension RoomDataModel {
    
    /// Количество ламп в комнате
    var lightCount: Int {
        return lightIds.count
    }
    
    /// Пустая ли комната
    var isEmpty: Bool {
        return lightIds.isEmpty
    }
}
