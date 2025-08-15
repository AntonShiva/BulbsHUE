//
//  SceneRepositoryProtocol.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Scene Repository Protocol
protocol SceneRepositoryProtocol {
    // MARK: - Read Operations
    func getAllScenes() -> AnyPublisher<[SceneEntity], Error>
    func getScene(by id: String) -> AnyPublisher<SceneEntity?, Error>
    func getActiveScenes() -> AnyPublisher<[SceneEntity], Error>
    
    // MARK: - Write Operations
    func activateScene(id: String) -> AnyPublisher<Void, Error>
    func createScene(name: String, lightIds: [String]) -> AnyPublisher<SceneEntity, Error>
    func updateScene(_ scene: SceneEntity) -> AnyPublisher<Void, Error>
    func deleteScene(id: String) -> AnyPublisher<Void, Error>
    
    // MARK: - Reactive Streams
    var scenesStream: AnyPublisher<[SceneEntity], Never> { get }
    func sceneStream(for id: String) -> AnyPublisher<SceneEntity?, Never>
}
