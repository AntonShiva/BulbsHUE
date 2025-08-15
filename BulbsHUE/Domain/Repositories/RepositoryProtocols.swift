//
//  RepositoryProtocols.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// Используем существующие модели из PhilipsHueV2
// BridgeCapabilities уже определена в PhilipsHueV2/Models/Bridge.swift

// MARK: - Bridge Repository Protocol
protocol BridgeRepositoryProtocol {
    func discoverBridges() -> AnyPublisher<[BridgeEntity], Error>
    func connectToBridge(bridge: BridgeEntity) -> AnyPublisher<String, Error> // Returns application key
    func getCurrentBridge() -> AnyPublisher<BridgeEntity?, Error>
    func getBridgeCapabilities() -> AnyPublisher<BridgeCapabilities?, Error>
}

// MARK: - Persistence Repository Protocol
protocol PersistenceRepositoryProtocol {
    func saveLightData(_ light: LightEntity) -> AnyPublisher<Void, Error>
    func loadLightData(id: String) -> AnyPublisher<LightEntity?, Error>
    func loadAllLightData() -> AnyPublisher<[LightEntity], Error>
    func deleteLightData(id: String) -> AnyPublisher<Void, Error>
    
    // Settings
    func saveSettings<T: Codable>(_ value: T, for key: String) -> AnyPublisher<Void, Error>
    func loadSettings<T: Codable>(for key: String, type: T.Type) -> AnyPublisher<T?, Error>
}
