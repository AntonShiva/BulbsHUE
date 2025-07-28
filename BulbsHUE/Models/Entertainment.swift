//
//  Entertainment.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Foundation

/// Конфигурация развлекательной зоны для streaming API
struct EntertainmentConfiguration: Codable, Identifiable {
    /// Уникальный идентификатор
    var id: String = UUID().uuidString
    
    /// Тип ресурса
    var type: String = "entertainment_configuration"
    
    /// Метаданные
    var metadata: EntertainmentMetadata = EntertainmentMetadata()
    
    /// Статус конфигурации
    var status: EntertainmentStatus?
    
    /// Список каналов (ламп)
    var channels: [EntertainmentChannel]?
    
    /// Позиции ламп в 3D пространстве
    var locations: EntertainmentLocations?
    
    /// Поток света
    var stream_proxy: StreamProxy?
}

/// Метаданные развлекательной конфигурации
struct EntertainmentMetadata: Codable {
    /// Название
    var name: String = "Entertainment area"
}

/// Статус развлекательной конфигурации
struct EntertainmentStatus: Codable {
    /// Активна ли конфигурация
    var active: Bool?
    
    /// Владелец активной сессии
    var owner: String?
}

/// Канал в развлекательной конфигурации
struct EntertainmentChannel: Codable {
    /// ID канала (0-9)
    var channel_id: Int?
    
    /// Позиция в пространстве
    var position: Position3D?
    
    /// Связанные сервисы (лампы)
    var members: [ChannelMember]?
}

/// Член канала
struct ChannelMember: Codable {
    /// Сервис (лампа)
    var service: ResourceIdentifier?
    
    /// Индекс (для gradient lights)
    var index: Int?
}

/// 3D позиция
struct Position3D: Codable {
    var x: Double?
    var y: Double?
    var z: Double?
}

/// Локации для развлекательной зоны
struct EntertainmentLocations: Codable {
    /// Сервисные локации
    var service_locations: [ServiceLocation]?
}

/// Локация сервиса
struct ServiceLocation: Codable {
    /// Сервис
    var service: ResourceIdentifier?
    
    /// Позиция
    var position: Position3D?
    
    /// Позиции для градиентных ламп
    var positions: [Position3D]?
}

/// Прокси для потоковой передачи
struct StreamProxy: Codable {
    /// Режим прокси
    var mode: String?
    
    /// Узел прокси
    var node: ResourceIdentifier?
}

