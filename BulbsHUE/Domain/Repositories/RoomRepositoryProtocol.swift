//
//  RoomRepositoryProtocol.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Room Repository Protocol
protocol RoomRepositoryProtocol: AnyObject {
    // MARK: - Read Operations
    func getAllRooms() -> AnyPublisher<[RoomEntity], Error>
    func getRoom(by id: String) -> AnyPublisher<RoomEntity?, Error>
    func getRoomsByType(_ type: RoomType) -> AnyPublisher<[RoomEntity], Error>
    func getActiveRooms() -> AnyPublisher<[RoomEntity], Error>
    
    // MARK: - Write Operations
    func createRoom(_ room: RoomEntity) -> AnyPublisher<Void, Error>
    func updateRoom(_ room: RoomEntity) -> AnyPublisher<Void, Error>
    func deleteRoom(id: String) -> AnyPublisher<Void, Error>
    func addLightToRoom(roomId: String, lightId: String) -> AnyPublisher<Void, Error>
    func removeLightFromRoom(roomId: String, lightId: String) -> AnyPublisher<Void, Error>
    func activateRoom(id: String) -> AnyPublisher<Void, Error>
    func deactivateRoom(id: String) -> AnyPublisher<Void, Error>
    
    // MARK: - Reactive Streams
    var roomsStream: AnyPublisher<[RoomEntity], Never> { get }
    func roomStream(for id: String) -> AnyPublisher<RoomEntity?, Never>
}
