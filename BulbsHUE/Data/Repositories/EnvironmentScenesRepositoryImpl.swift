//
//  EnvironmentScenesRepositoryImpl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import Foundation

// MARK: - Environment Scenes Repository Implementation

/// Реализация репозитория для работы с пресетами сцен окружения
final class EnvironmentScenesRepositoryImpl: EnvironmentScenesRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let localDataSource: EnvironmentScenesLocalDataSource
    
    // MARK: - Private Properties
    
    private var cachedScenes: [EnvironmentSceneEntity] = []
    
    // MARK: - Initialization
    
    init(localDataSource: EnvironmentScenesLocalDataSource) {
        self.localDataSource = localDataSource
    }
    
    // MARK: - EnvironmentScenesRepositoryProtocol
    
    func getAllScenes() async throws -> [EnvironmentSceneEntity] {
        if cachedScenes.isEmpty {
            cachedScenes = await localDataSource.loadScenes()
        }
        return cachedScenes
    }
    
    func getScenes(
        filterType: EnvironmentFilterType,
        section: EnvironmentSection
    ) async throws -> [EnvironmentSceneEntity] {
        let allScenes = try await getAllScenes()
        return allScenes.filter { scene in
            scene.filterType == filterType && scene.section == section
        }
    }
    
    func toggleFavorite(sceneId: String) async throws -> EnvironmentSceneEntity {
        guard let index = cachedScenes.firstIndex(where: { $0.id == sceneId }) else {
            throw EnvironmentRepositoryError.sceneNotFound(sceneId)
        }
        
        let currentScene = cachedScenes[index]
        let updatedScene = EnvironmentSceneEntity(
            id: currentScene.id,
            name: currentScene.name,
            imageAssetName: currentScene.imageAssetName,
            section: currentScene.section,
            filterType: currentScene.filterType,
            isFavorite: !currentScene.isFavorite,
            isSelected: currentScene.isSelected
        )
        
        cachedScenes[index] = updatedScene
        
        // Сохраняем изменения в локальное хранилище
        await localDataSource.updateScene(updatedScene)
        
        return updatedScene
    }
    
    func selectScene(sceneId: String) async throws -> [EnvironmentSceneEntity] {
        // Снимаем выделение со всех сцен
        for index in cachedScenes.indices {
            if cachedScenes[index].isSelected {
                let scene = cachedScenes[index]
                cachedScenes[index] = EnvironmentSceneEntity(
                    id: scene.id,
                    name: scene.name,
                    imageAssetName: scene.imageAssetName,
                    section: scene.section,
                    filterType: scene.filterType,
                    isFavorite: scene.isFavorite,
                    isSelected: false
                )
            }
        }
        
        // Выделяем выбранную сцену
        guard let index = cachedScenes.firstIndex(where: { $0.id == sceneId }) else {
            throw EnvironmentRepositoryError.sceneNotFound(sceneId)
        }
        
        let currentScene = cachedScenes[index]
        cachedScenes[index] = EnvironmentSceneEntity(
            id: currentScene.id,
            name: currentScene.name,
            imageAssetName: currentScene.imageAssetName,
            section: currentScene.section,
            filterType: currentScene.filterType,
            isFavorite: currentScene.isFavorite,
            isSelected: true
        )
        
        // Сохраняем изменения
        await localDataSource.updateScene(cachedScenes[index])
        
        return cachedScenes
    }
}

// MARK: - Repository Errors

enum EnvironmentRepositoryError: Error, LocalizedError {
    case sceneNotFound(String)
    case loadingFailed
    case savingFailed
    
    var errorDescription: String? {
        switch self {
        case .sceneNotFound(let id):
            return "Scene with ID \(id) not found"
        case .loadingFailed:
            return "Failed to load environment scenes"
        case .savingFailed:
            return "Failed to save environment scene changes"
        }
    }
}
