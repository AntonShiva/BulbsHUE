//
//  EnvironmentUseCases.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import Foundation

// MARK: - Environment Scenes Use Case Protocol

/// Протокол для управления сценами окружения
protocol EnvironmentScenesUseCaseProtocol {
    /// Получить все доступные сцены
    func getAllScenes() async throws -> [EnvironmentSceneEntity]
    
    /// Получить сцены для определенного фильтра и секции
    func getScenes(
        for filterType: EnvironmentFilterType,
        section: EnvironmentSection,
        favoritesOnly: Bool
    ) async throws -> [EnvironmentSceneEntity]
    
    /// Переключить статус избранного для сцены
    func toggleFavorite(sceneId: String) async throws -> EnvironmentSceneEntity
    
    /// Выбрать сцену (снять выделение с остальных)
    func selectScene(sceneId: String) async throws -> [EnvironmentSceneEntity]
}

// MARK: - Environment Scenes Use Case Implementation

/// Реализация Use Case для работы со сценами окружения
@MainActor
final class EnvironmentScenesUseCase: EnvironmentScenesUseCaseProtocol {
    
    // MARK: - Dependencies
    
    private let repository: EnvironmentScenesRepositoryProtocol
    
    // MARK: - Initialization
    
    init(repository: EnvironmentScenesRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    func getAllScenes() async throws -> [EnvironmentSceneEntity] {
        return try await repository.getAllScenes()
    }
    
    func getScenes(
        for filterType: EnvironmentFilterType,
        section: EnvironmentSection,
        favoritesOnly: Bool = false
    ) async throws -> [EnvironmentSceneEntity] {
        let allScenes = try await repository.getAllScenes()
        
        let filteredScenes = allScenes.filter { scene in
            scene.filterType == filterType && 
            scene.section == section &&
            (!favoritesOnly || scene.isFavorite)
        }
        
        return filteredScenes
    }
    
    func toggleFavorite(sceneId: String) async throws -> EnvironmentSceneEntity {
        return try await repository.toggleFavorite(sceneId: sceneId)
    }
    
    func selectScene(sceneId: String) async throws -> [EnvironmentSceneEntity] {
        return try await repository.selectScene(sceneId: sceneId)
    }
}
