//
//  EnvironmentRepositoryProtocol.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import Foundation

// MARK: - Environment Scenes Repository Protocol

/// Протокол репозитория для работы с пресетами сцен окружения
protocol EnvironmentScenesRepositoryProtocol {
    /// Получить все доступные сцены
    func getAllScenes() async throws -> [EnvironmentSceneEntity]
    
    /// Переключить статус избранного для сцены
    func toggleFavorite(sceneId: String) async throws -> EnvironmentSceneEntity
    
    /// Выбрать сцену (автоматически снимает выделение с остальных)
    func selectScene(sceneId: String) async throws -> [EnvironmentSceneEntity]
    
    /// Получить сцены для определенного фильтра и секции
    func getScenes(
        filterType: EnvironmentFilterType,
        section: EnvironmentSection
    ) async throws -> [EnvironmentSceneEntity]
}
