//
//  RoomsViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel для управления комнатами в Environment
/// Следует принципам MVVM и SOLID - Single Responsibility Principle
@MainActor
final class RoomsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Список созданных комнат
    @Published var rooms: [RoomEntity] = []
    
    /// Статус загрузки комнат
    @Published var isLoading: Bool = false
    
    /// Ошибка загрузки комнат
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    /// Use Case для работы с комнатами
    private let getRoomsUseCase: GetRoomsUseCaseProtocol
    private let deleteRoomUseCase: DeleteRoomUseCaseProtocol
    
    /// Подписки Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Инициализация с внедрением зависимостей (Dependency Injection)
    /// - Parameters:
    ///   - getRoomsUseCase: Use Case для получения комнат
    ///   - deleteRoomUseCase: Use Case для удаления комнат
    init(
        getRoomsUseCase: GetRoomsUseCaseProtocol,
        deleteRoomUseCase: DeleteRoomUseCaseProtocol
    ) {
        self.getRoomsUseCase = getRoomsUseCase
        self.deleteRoomUseCase = deleteRoomUseCase
        
        loadRooms()
    }
    
    // MARK: - Public Methods
    
    /// Загрузить список комнат
    func loadRooms() {
        isLoading = true
        error = nil
        
        print("🔍 RoomsViewModel: Запрашиваем список комнат...")
        
        getRoomsUseCase.execute(())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                        print("❌ Ошибка загрузки комнат: \(error)")
                    }
                },
                receiveValue: { [weak self] rooms in
                    self?.rooms = rooms
                    print("✅ RoomsViewModel: Загружено комнат: \(rooms.count)")
                    if !rooms.isEmpty {
                        print("   Комнаты: \(rooms.map { "\($0.name) (\($0.lightCount) ламп)" })")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обновить список комнат (pull-to-refresh)
    func refreshRooms() {
        loadRooms()
    }
    
    /// Удалить комнату
    /// - Parameter roomId: ID комнаты для удаления
    func removeRoom(_ roomId: String) {
        guard let room = rooms.first(where: { $0.id == roomId }) else {
            print("❌ Комната с ID \(roomId) не найдена")
            return
        }
        
        deleteRoomUseCase.execute(roomId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Ошибка удаления комнаты: \(error)")
                    }
                },
                receiveValue: { [weak self] _ in
                    // Удаляем из локального массива
                    self?.rooms.removeAll { $0.id == roomId }
                    print("✅ Комната \(room.name) удалена")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    /// Количество комнат
    var roomsCount: Int {
        rooms.count
    }
    
    /// Есть ли созданные комнаты
    var hasRooms: Bool {
        !rooms.isEmpty
    }
    
    /// Активные комнаты
    var activeRooms: [RoomEntity] {
        rooms.filter { $0.isActive }
    }
    
    /// Пустые комнаты (без ламп)
    var emptyRooms: [RoomEntity] {
        rooms.filter { $0.isEmpty }
    }
}

// MARK: - Mock для тестирования

extension RoomsViewModel {
    /// Создать mock ViewModel для превью и тестов
    static func createMock() -> RoomsViewModel {
        return RoomsViewModel(
            getRoomsUseCase: MockGetRoomsUseCase(),
            deleteRoomUseCase: MockDeleteRoomUseCase()
        )
    }
}

// MARK: - Protocol Definitions

/// Протокол для получения комнат (Dependency Inversion Principle)
protocol GetRoomsUseCaseProtocol {
    func execute(_ input: Void) -> AnyPublisher<[RoomEntity], Error>
}

/// Протокол для удаления комнат (Dependency Inversion Principle)
protocol DeleteRoomUseCaseProtocol {
    func execute(_ roomId: String) -> AnyPublisher<Void, Error>
}

// MARK: - Mock Implementations

private struct MockGetRoomsUseCase: GetRoomsUseCaseProtocol {
    func execute(_ input: Void) -> AnyPublisher<[RoomEntity], Error> {
        // ✅ ИСПРАВЛЕНО: При первом запуске комнат нет - пустой список
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

private struct MockDeleteRoomUseCase: DeleteRoomUseCaseProtocol {
    func execute(_ roomId: String) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
