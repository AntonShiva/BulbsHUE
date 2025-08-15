//
//  BridgeEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - Domain Entity для моста
/// Чистая доменная модель моста без зависимостей от API
struct BridgeEntity: Equatable, Identifiable, Codable {
    let id: String
    let name: String
    let ipAddress: String
    let modelId: String?
    let swVersion: String?
    let applicationKey: String?
    let isConnected: Bool
    let lastSeen: Date?
    
    /// Инициализатор из существующей модели Bridge
    init(from bridge: Bridge) {
        self.id = bridge.id.isEmpty ? UUID().uuidString : bridge.id
        self.name = bridge.name ?? "Philips Hue Bridge"
        self.ipAddress = bridge.internalipaddress
        self.modelId = nil // Bridge не содержит modelId, получается из BridgeConfig
        self.swVersion = nil // Bridge не содержит swVersion, получается из BridgeConfig
        self.applicationKey = nil // Устанавливается отдельно после подключения
        self.isConnected = false // Устанавливается отдельно
        self.lastSeen = Date()
    }
    
    /// Инициализатор из BridgeConfig (получается после подключения)
    init(from bridge: Bridge, config: BridgeConfig) {
        self.id = bridge.id.isEmpty ? UUID().uuidString : bridge.id
        self.name = config.name ?? bridge.name ?? "Philips Hue Bridge"
        self.ipAddress = bridge.internalipaddress
        self.modelId = config.modelid
        self.swVersion = config.swversion
        self.applicationKey = nil // Устанавливается отдельно после подключения
        self.isConnected = true // Если есть config, значит подключены
        self.lastSeen = Date()
    }
    
    /// Инициализатор для создания новой сущности
    init(id: String, 
         name: String, 
         ipAddress: String, 
         modelId: String? = nil, 
         swVersion: String? = nil, 
         applicationKey: String? = nil, 
         isConnected: Bool = false, 
         lastSeen: Date? = nil) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.modelId = modelId
        self.swVersion = swVersion
        self.applicationKey = applicationKey
        self.isConnected = isConnected
        self.lastSeen = lastSeen
    }
}
