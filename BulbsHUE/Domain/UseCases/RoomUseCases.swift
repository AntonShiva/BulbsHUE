//
//  RoomUseCases.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Create Room Use Case
struct CreateRoomUseCase: UseCase {
    private let roomRepository: RoomRepositoryProtocol
    
    init(roomRepository: RoomRepositoryProtocol) {
        self.roomRepository = roomRepository
    }
    
    struct Input {
        let name: String
        let type: RoomSubType
        let iconName: String
    }
    
    func execute(_ input: Input) -> AnyPublisher<RoomEntity, Error> {
        // Валидация входных данных
        guard !input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Fail(error: RoomError.invalidName)
                .eraseToAnyPublisher()
        }
        
        let room = RoomEntity(
            id: UUID().uuidString,
            name: input.name,
            type: input.type,
            iconName: input.iconName,
            lightIds: [],
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        return roomRepository.createRoom(room)
            .map { _ in room }
            .eraseToAnyPublisher()
    }
}

// MARK: - Create Room With Lights Use Case
struct CreateRoomWithLightsUseCase: UseCase {
    private let roomRepository: RoomRepositoryProtocol
    private let lightRepository: LightRepositoryProtocol
    
    init(roomRepository: RoomRepositoryProtocol, lightRepository: LightRepositoryProtocol) {
        self.roomRepository = roomRepository
        self.lightRepository = lightRepository
    }
    
    struct Input {
        let roomName: String
        let roomType: RoomSubType
        let iconName: String // ✅ Иконка подтипа
        let lightIds: [String]
    }
    
    func execute(_ input: Input) -> AnyPublisher<RoomEntity, Error> {
        // Валидация входных данных
        guard !input.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Fail(error: RoomError.invalidName)
                .eraseToAnyPublisher()
        }
        
        guard !input.lightIds.isEmpty else {
            return Fail(error: RoomError.noLightsProvided)
                .eraseToAnyPublisher()
        }
        
        // ✅ ПРОВЕРКА ЧЕРЕЗ РЕАЛЬНЫЙ REPOSITORY
        // Проверяем, что все лампы существуют
        let lightChecks = input.lightIds.map { lightId in
            lightRepository.getLight(by: lightId)
                .map { light -> Bool in
                    return light != nil
                }
        }
        
        print("🔍 Проверяем существование ламп: \(input.lightIds)")
        
        return Publishers.MergeMany(lightChecks)
            .collect()
            .flatMap { results -> AnyPublisher<RoomEntity, Error> in
                // Проверяем, что все лампы найдены
                guard results.allSatisfy({ $0 }) else {
                    print("❌ Не все лампы найдены. Результаты: \(results)")
                    return Fail(error: RoomError.lightNotFound)
                        .eraseToAnyPublisher()
                }
                
                print("✅ Все лампы найдены, создаем комнату")
                
                // Создаем комнату
                let room = RoomEntity(
                    id: UUID().uuidString,
                    name: input.roomName,
                    type: input.roomType,
                    iconName: input.iconName, // ✅ Сохраняем иконку
                    lightIds: input.lightIds,
                    isActive: true,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                return self.roomRepository.createRoom(room)
                    .map { _ in room }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Add Light To Room Use Case
struct AddLightToRoomUseCase: UseCase {
    private let roomRepository: RoomRepositoryProtocol
    private let lightRepository: LightRepositoryProtocol
    
    init(roomRepository: RoomRepositoryProtocol, lightRepository: LightRepositoryProtocol) {
        self.roomRepository = roomRepository
        self.lightRepository = lightRepository
    }
    
    struct Input {
        let lightId: String
        let roomId: String
    }
    
    func execute(_ input: Input) -> AnyPublisher<Void, Error> {
        // Проверяем, что лампа существует
        return lightRepository.getLight(by: input.lightId)
            .flatMap { light -> AnyPublisher<Void, Error> in
                guard light != nil else {
                    return Fail(error: RoomError.lightNotFound)
                        .eraseToAnyPublisher()
                }
                
                // Проверяем, что комната существует
                return self.roomRepository.getRoom(by: input.roomId)
                    .flatMap { room -> AnyPublisher<Void, Error> in
                        guard room != nil else {
                            return Fail(error: RoomError.roomNotFound)
                                .eraseToAnyPublisher()
                        }
                        
                        return self.roomRepository.addLightToRoom(
                            roomId: input.roomId,
                            lightId: input.lightId
                        )
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Get Room Lights Use Case
struct GetRoomLightsUseCase: UseCase {
    private let roomRepository: RoomRepositoryProtocol
    private let lightRepository: LightRepositoryProtocol
    
    init(roomRepository: RoomRepositoryProtocol, lightRepository: LightRepositoryProtocol) {
        self.roomRepository = roomRepository
        self.lightRepository = lightRepository
    }
    
    struct Input {
        let roomId: String
    }
    
    func execute(_ input: Input) -> AnyPublisher<[LightEntity], Error> {
        return roomRepository.getRoom(by: input.roomId)
            .flatMap { room -> AnyPublisher<[LightEntity], Error> in
                guard let room = room else {
                    return Fail(error: RoomError.roomNotFound)
                        .eraseToAnyPublisher()
                }
                
                // Получаем все лампы и фильтруем по ID комнаты
                return self.lightRepository.getAllLights()
                    .map { lights in
                        lights.filter { room.lightIds.contains($0.id) }
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Get Rooms Use Case
struct GetRoomsUseCase: UseCase, GetRoomsUseCaseProtocol {
    private let roomRepository: RoomRepositoryProtocol
    
    init(roomRepository: RoomRepositoryProtocol) {
        self.roomRepository = roomRepository
    }
    
    func execute(_ input: Void) -> AnyPublisher<[RoomEntity], Error> {
        return roomRepository.getAllRooms()
    }
}

// MARK: - Delete Room Use Case
struct DeleteRoomUseCase: UseCase, DeleteRoomUseCaseProtocol {
    private let roomRepository: RoomRepositoryProtocol
    
    init(roomRepository: RoomRepositoryProtocol) {
        self.roomRepository = roomRepository
    }
    
    func execute(_ roomId: String) -> AnyPublisher<Void, Error> {
        return roomRepository.deleteRoom(id: roomId)
    }
}

// MARK: - Room Errors
enum RoomError: Error, LocalizedError {
    case roomNotFound
    case lightNotFound
    case invalidName
    case roomAlreadyExists
    case cannotDeleteNonEmptyRoom
    case noLightsProvided
    
    var errorDescription: String? {
        switch self {
        case .roomNotFound:
            return "Room not found"
        case .lightNotFound:
            return "Light not found"
        case .invalidName:
            return "Invalid room name"
        case .roomAlreadyExists:
            return "Room with this name already exists"
        case .cannotDeleteNonEmptyRoom:
            return "Cannot delete room with lights"
        case .noLightsProvided:
            return "No lights provided for room creation"
        }
    }
}
