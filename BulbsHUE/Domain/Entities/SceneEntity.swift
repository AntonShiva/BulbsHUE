//
//  SceneEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - Domain Entity для сцены
/// Чистая доменная модель сцены без зависимостей от API
struct SceneEntity: Equatable, Identifiable {
    let id: String
    let name: String
    let lightIds: [String]
    let isActive: Bool
    let createdAt: Date?
    let lastUsed: Date?
    
    /// Инициализатор из существующей модели HueScene
    init(from scene: HueScene) {
        self.id = scene.id.isEmpty ? UUID().uuidString : scene.id
        self.name = scene.metadata.name
        // Извлекаем ID ламп из actions, если доступно
        self.lightIds = scene.actions.compactMap { $0.target?.rid }
        self.isActive = false // HueScene не содержит информацию об активности
        self.createdAt = Date() // API не предоставляет дату создания
        self.lastUsed = nil
    }
    
    /// Инициализатор для создания новой сущности
    init(id: String, 
         name: String, 
         lightIds: [String], 
         isActive: Bool = false, 
         createdAt: Date? = nil, 
         lastUsed: Date? = nil) {
        self.id = id
        self.name = name
        self.lightIds = lightIds
        self.isActive = isActive
        self.createdAt = createdAt ?? Date()
        self.lastUsed = lastUsed
    }
}
