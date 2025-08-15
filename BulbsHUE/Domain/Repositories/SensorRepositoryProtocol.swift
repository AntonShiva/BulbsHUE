//
//  SensorRepositoryProtocol.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Sensor Repository Protocol
protocol SensorRepositoryProtocol {
    // MARK: - Read Operations
    func getAllSensors() -> AnyPublisher<[SensorEntity], Error>
    func getSensor(by id: String) -> AnyPublisher<SensorEntity?, Error>
    func getSensorsByType(_ type: SensorEntity.SensorType) -> AnyPublisher<[SensorEntity], Error>
    func getReachableSensors() -> AnyPublisher<[SensorEntity], Error>
    
    // MARK: - Reactive Streams
    var sensorsStream: AnyPublisher<[SensorEntity], Never> { get }
    func sensorStream(for id: String) -> AnyPublisher<SensorEntity?, Never>
}
