//
//  Bridge.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// Модель моста Hue
struct Bridge: Codable, Identifiable, Hashable {
    /// Уникальный ID моста
    var id: String = ""
    
    /// IP адрес в локальной сети
    var internalipaddress: String = ""
    
    /// Порт (обычно 443 для HTTPS)
    var port: Int = 443
    
    /// MAC адрес
    var macaddress: String?
    
    /// Имя моста
    var name: String?
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(internalipaddress)
    }
    
    static func == (lhs: Bridge, rhs: Bridge) -> Bool {
        return lhs.id == rhs.id && lhs.internalipaddress == rhs.internalipaddress
    }
}

/// Конфигурация моста
struct BridgeConfig: Codable {
    /// Имя моста
    var name: String?
    
    /// Версия ПО
    var swversion: String?
    
    /// Версия API
    var apiversion: String?
    
    /// MAC адрес
    var mac: String?
    
    /// ID моста
    var bridgeid: String?
    
    /// Новый с завода
    var factorynew: Bool?
    
    /// Заменяет мост с ID
    var replacesbridgeid: String?
    
    /// Модель
    var modelid: String?
    
    /// Версия datastore
    var datastoreversion: String?
}

/// Возможности моста (лимиты)
struct BridgeCapabilities: Codable {
    /// Лимиты ресурсов
    var resources: ResourceLimits?
    
    /// Лимиты потоковой передачи
    var streaming: StreamingLimits?
    
    /// Поддерживаемые часовые пояса
    var timezones: [String]?
}

/// Лимиты ресурсов
struct ResourceLimits: Codable {
    /// Максимум ламп
    var lights: Int?
    
    /// Максимум сенсоров
    var sensors: Int?
    
    /// Максимум групп
    var groups: Int?
    
    /// Максимум сцен
    var scenes: Int?
    
    /// Максимум правил
    var rules: Int?
    
    /// Максимум расписаний
    var schedules: Int?
    
    /// Максимум ресурсных ссылок
    var resourcelinks: Int?
    
    /// Максимум записей в белом списке
    var whitelists: Int?
}

/// Лимиты потоковой передачи
struct StreamingLimits: Codable {
    /// Максимум активных потоков
    var total: Int?
    
    /// Максимум развлекательных областей
    var entertainment: Int?
}
