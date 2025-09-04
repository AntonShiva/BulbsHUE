//
//  RoomRepositoryImpl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/11/25.
//

import Foundation
import SwiftData
import Combine

/// Реализация RoomRepositoryProtocol через SwiftData
/// Обеспечивает персистентное хранение комнат с полной CRUD функциональностью
final class RoomRepositoryImpl: RoomRepositoryProtocol {
    
    // MARK: - Properties
    
    /// Контекст модели SwiftData для операций с данными
    private let modelContext: ModelContext
    
    /// Subject для реактивного обновления комнат
    private let roomsSubject = CurrentValueSubject<[RoomEntity], Never>([])
    
    /// Subjects для отдельных комнат (кэш)
    private var roomSubjects: [String: CurrentValueSubject<RoomEntity?, Never>] = [:]
    
    /// Отслеживание времени доступа к subjects для автоматической очистки
    private var roomSubjectsAccess: [String: Date] = [:]
    
    /// Cancellables для stream операций
    private var streamCancellables = Set<AnyCancellable>()
    
    /// Максимальное количество активных room subjects (предотвращение утечек памяти)
    private let maxRoomSubjects = 50
    
    /// Время жизни неиспользуемых subjects (5 минут)
    private let subjectLifetime: TimeInterval = 300
    
    // MARK: - Initialization
    
    /// Инициализация с контекстом SwiftData
    /// - Parameter modelContext: Контекст модели для работы с данными
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // ✅ ДОБАВЛЕНО: Регистрируем репозиторий в диагностике памяти
        MemoryLeakDiagnosticsService.registerRepository(self, name: "RoomRepositoryImpl_\(ObjectIdentifier(self).hashValue)")
        
        // Загружаем начальные данные для реактивного стрима
        loadInitialRooms()
    }
    
    // MARK: - Read Operations
    
    /// Получить все комнаты
    /// - Returns: Publisher с массивом комнат
    func getAllRooms() -> AnyPublisher<[RoomEntity], Error> {
        let descriptor = FetchDescriptor<RoomDataModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let roomDataModels = try modelContext.fetch(descriptor)
            let roomEntities = roomDataModels.map { $0.toRoomEntity() }
            
            // Обновляем реактивный стрим
            roomsSubject.send(roomEntities)
            
            return Just(roomEntities)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Получить комнату по ID
    /// - Parameter id: ID комнаты
    /// - Returns: Publisher с комнатой или nil
    func getRoom(by id: String) -> AnyPublisher<RoomEntity?, Error> {
        let descriptor = FetchDescriptor<RoomDataModel>(
            predicate: #Predicate { $0.roomId == id }
        )
        
        do {
            let roomDataModels = try modelContext.fetch(descriptor)
            let roomEntity = roomDataModels.first?.toRoomEntity()
            
            // Обновляем subject для конкретной комнаты
            updateRoomSubject(for: id, with: roomEntity)
            
            return Just(roomEntity)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Получить комнаты по типу
    /// - Parameter type: Тип комнат
    /// - Returns: Publisher с массивом комнат указанного типа
    func getRoomsByType(_ type: RoomType) -> AnyPublisher<[RoomEntity], Error> {
        return getAllRooms()
            .map { rooms in
                rooms.filter { $0.type.parentEnvironmentType == type }
            }
            .eraseToAnyPublisher()
    }
    
    /// Получить активные комнаты
    /// - Returns: Publisher с массивом активных комнат
    func getActiveRooms() -> AnyPublisher<[RoomEntity], Error> {
        let descriptor = FetchDescriptor<RoomDataModel>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let roomDataModels = try modelContext.fetch(descriptor)
            let roomEntities = roomDataModels.map { $0.toRoomEntity() }
            
            return Just(roomEntities)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Write Operations
    
    /// Создать новую комнату
    /// - Parameter room: Сущность комнаты для создания
    /// - Returns: Publisher с результатом операции
    func createRoom(_ room: RoomEntity) -> AnyPublisher<Void, Error> {
        do {
            // Проверяем, не существует ли уже комната с таким ID
            let existingRoom = try fetchRoomDataModel(by: room.id)
            if existingRoom != nil {
                return Fail(error: RoomRepositoryError.roomAlreadyExists)
                    .eraseToAnyPublisher()
            }
            
            // Создаем новую модель данных
            let roomDataModel = RoomDataModel.fromRoomEntity(room)
            modelContext.insert(roomDataModel)
            
            // Сохраняем контекст
            try modelContext.save()
            
            print("✅ Комната '\(room.name)' успешно сохранена в SwiftData")
            print("   ID: \(room.id)")
            print("   Тип: \(room.type)")
            print("   Иконка: \(room.iconName)")
            print("   Количество ламп: \(room.lightCount)")
            
            // Обновляем реактивные стримы
            refreshReactiveStreams()
            
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            
        } catch {
            print("❌ Ошибка создания комнаты: \(error)")
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Обновить существующую комнату
    /// - Parameter room: Обновленная сущность комнаты
    /// - Returns: Publisher с результатом операции
    func updateRoom(_ room: RoomEntity) -> AnyPublisher<Void, Error> {
        do {
            guard let roomDataModel = try fetchRoomDataModel(by: room.id) else {
                return Fail(error: RoomRepositoryError.roomNotFound)
                    .eraseToAnyPublisher()
            }
            
            // Обновляем данные
            roomDataModel.updateFromRoomEntity(room)
            
            // Сохраняем контекст
            try modelContext.save()
            
            print("✅ Комната '\(room.name)' успешно обновлена")
            
            // Обновляем реактивные стримы
            refreshReactiveStreams()
            
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            
        } catch {
            print("❌ Ошибка обновления комнаты: \(error)")
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Удалить комнату
    /// - Parameter id: ID комнаты для удаления
    /// - Returns: Publisher с результатом операции
    func deleteRoom(id: String) -> AnyPublisher<Void, Error> {
        do {
            guard let roomDataModel = try fetchRoomDataModel(by: id) else {
                return Fail(error: RoomRepositoryError.roomNotFound)
                    .eraseToAnyPublisher()
            }
            
            let roomName = roomDataModel.name
            
            // Удаляем из контекста
            modelContext.delete(roomDataModel)
            
            // Сохраняем контекст
            try modelContext.save()
            
            print("✅ Комната '\(roomName)' успешно удалена из SwiftData")
            
            // Обновляем реактивные стримы
            refreshReactiveStreams()
            
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            
        } catch {
            print("❌ Ошибка удаления комнаты: \(error)")
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Добавить лампу в комнату
    /// - Parameters:
    ///   - roomId: ID комнаты
    ///   - lightId: ID лампы
    /// - Returns: Publisher с результатом операции
    func addLightToRoom(roomId: String, lightId: String) -> AnyPublisher<Void, Error> {
        do {
            guard let roomDataModel = try fetchRoomDataModel(by: roomId) else {
                return Fail(error: RoomRepositoryError.roomNotFound)
                    .eraseToAnyPublisher()
            }
            
            // Добавляем лампу
            roomDataModel.addLight(lightId)
            
            // Сохраняем контекст
            try modelContext.save()
            
            print("✅ Лампа \(lightId) добавлена в комнату '\(roomDataModel.name)'")
            
            // Обновляем реактивные стримы
            refreshReactiveStreams()
            
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            
        } catch {
            print("❌ Ошибка добавления лампы в комнату: \(error)")
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Удалить лампу из комнаты
    /// - Parameters:
    ///   - roomId: ID комнаты
    ///   - lightId: ID лампы
    /// - Returns: Publisher с результатом операции
    func removeLightFromRoom(roomId: String, lightId: String) -> AnyPublisher<Void, Error> {
        do {
            guard let roomDataModel = try fetchRoomDataModel(by: roomId) else {
                return Fail(error: RoomRepositoryError.roomNotFound)
                    .eraseToAnyPublisher()
            }
            
            // Удаляем лампу
            roomDataModel.removeLight(lightId)
            
            // Сохраняем контекст
            try modelContext.save()
            
            print("✅ Лампа \(lightId) удалена из комнаты '\(roomDataModel.name)'")
            
            // Обновляем реактивные стримы
            refreshReactiveStreams()
            
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            
        } catch {
            print("❌ Ошибка удаления лампы из комнаты: \(error)")
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Активировать комнату
    /// - Parameter id: ID комнаты
    /// - Returns: Publisher с результатом операции
    func activateRoom(id: String) -> AnyPublisher<Void, Error> {
        return updateRoomActiveStatus(id: id, isActive: true)
    }
    
    /// Деактивировать комнату
    /// - Parameter id: ID комнаты
    /// - Returns: Publisher с результатом операции
    func deactivateRoom(id: String) -> AnyPublisher<Void, Error> {
        return updateRoomActiveStatus(id: id, isActive: false)
    }
    
    // MARK: - Reactive Streams
    
    /// Реактивный стрим всех комнат
    var roomsStream: AnyPublisher<[RoomEntity], Never> {
        return roomsSubject.eraseToAnyPublisher()
    }
    
    /// Реактивный стрим для конкретной комнаты
    /// - Parameter id: ID комнаты
    /// - Returns: Publisher с комнатой или nil
    func roomStream(for id: String) -> AnyPublisher<RoomEntity?, Never> {
        // ✅ ИСПРАВЛЕНО: Обновляем время доступа для трекинга
        roomSubjectsAccess[id] = Date()
        
        // ✅ ИСПРАВЛЕНО: Проверяем лимит subjects и очищаем при необходимости
        if roomSubjects.count >= maxRoomSubjects {
            cleanupUnusedSubjects()
        }
        
        if let existingSubject = roomSubjects[id] {
            return existingSubject.eraseToAnyPublisher()
        }
        
        // Создаем новый subject для этой комнаты
        let newSubject = CurrentValueSubject<RoomEntity?, Never>(nil)
        roomSubjects[id] = newSubject
        
        // ✅ ИСПРАВЛЕНО: Правильное сохранение подписки в cancellables
        getRoom(by: id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { room in
                    newSubject.send(room)
                }
            )
            .store(in: &streamCancellables)
        
        return newSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    /// Получить RoomDataModel по ID
    /// - Parameter id: ID комнаты
    /// - Returns: RoomDataModel или nil
    /// - Throws: Ошибка SwiftData
    private func fetchRoomDataModel(by id: String) throws -> RoomDataModel? {
        let descriptor = FetchDescriptor<RoomDataModel>(
            predicate: #Predicate { $0.roomId == id }
        )
        
        let roomDataModels = try modelContext.fetch(descriptor)
        return roomDataModels.first
    }
    
    /// Обновить статус активности комнаты
    /// - Parameters:
    ///   - id: ID комнаты
    ///   - isActive: Новый статус активности
    /// - Returns: Publisher с результатом операции
    private func updateRoomActiveStatus(id: String, isActive: Bool) -> AnyPublisher<Void, Error> {
        do {
            guard let roomDataModel = try fetchRoomDataModel(by: id) else {
                return Fail(error: RoomRepositoryError.roomNotFound)
                    .eraseToAnyPublisher()
            }
            
            roomDataModel.isActive = isActive
            roomDataModel.updatedAt = Date()
            
            // Сохраняем контекст
            try modelContext.save()
            
            let statusText = isActive ? "активирована" : "деактивирована"
            print("✅ Комната '\(roomDataModel.name)' \(statusText)")
            
            // Обновляем реактивные стримы
            refreshReactiveStreams()
            
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            
        } catch {
            print("❌ Ошибка изменения статуса комнаты: \(error)")
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Загрузить начальные данные для реактивных стримов
    private func loadInitialRooms() {
        getAllRooms()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Ошибка загрузки начальных комнат: \(error)")
                    }
                },
                receiveValue: { _ in
                    // Данные уже обновлены в getAllRooms()
                }
            )
            .store(in: &streamCancellables)
    }
    
    /// Обновить все реактивные стримы
    private func refreshReactiveStreams() {
        // Обновляем общий стрим комнат
        getAllRooms()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    // Данные уже обновлены в getAllRooms()
                }
            )
            .store(in: &streamCancellables)
        
        // Обновляем стримы отдельных комнат
        for (roomId, _) in roomSubjects {
            getRoom(by: roomId)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { room in
                        self.updateRoomSubject(for: roomId, with: room)
                    }
                )
                .store(in: &streamCancellables)
        }
    }
    
    /// Обновить subject для конкретной комнаты
    /// - Parameters:
    ///   - roomId: ID комнаты
    ///   - room: Новые данные комнаты
    private func updateRoomSubject(for roomId: String, with room: RoomEntity?) {
        if let subject = roomSubjects[roomId] {
            subject.send(room)
            // Обновляем время доступа
            roomSubjectsAccess[roomId] = Date()
        }
    }
    
    // MARK: - Memory Management
    
    /// Очистка неиспользуемых subjects для предотвращения утечек памяти
    private func cleanupUnusedSubjects() {
        let cutoffDate = Date().addingTimeInterval(-subjectLifetime)
        let beforeCount = roomSubjects.count
        
        // Находим комнаты для удаления
        let roomsToRemove = roomSubjectsAccess.compactMap { (roomId, lastAccess) in
            lastAccess < cutoffDate ? roomId : nil
        }
        
        // Завершаем subjects перед удалением
        for roomId in roomsToRemove {
            roomSubjects[roomId]?.send(completion: .finished)
            roomSubjects.removeValue(forKey: roomId)
            roomSubjectsAccess.removeValue(forKey: roomId)
        }
        
        print("🧹 RoomRepository: Очищено \(roomsToRemove.count) неиспользуемых subjects (было: \(beforeCount), стало: \(roomSubjects.count))")
    }
    
    // MARK: - Cleanup
    
    /// ✅ ДОБАВЛЕНО: Правильная очистка ресурсов при деинициализации
    deinit {
        print("♻️ RoomRepositoryImpl деинициализация - очистка \(roomSubjects.count) subjects")
        
        // Завершаем все subjects
        roomsSubject.send(completion: .finished)
        roomSubjects.values.forEach { $0.send(completion: .finished) }
        roomSubjects.removeAll()
        roomSubjectsAccess.removeAll()
        
        // Отменяем все подписки
        streamCancellables.forEach { $0.cancel() }
        streamCancellables.removeAll()
        
        print("✅ RoomRepositoryImpl ресурсы очищены")
    }
}

// MARK: - Repository Errors

enum RoomRepositoryError: Error, LocalizedError {
    case roomNotFound
    case roomAlreadyExists
    case invalidData
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .roomNotFound:
            return "Комната не найдена"
        case .roomAlreadyExists:
            return "Комната с таким ID уже существует"
        case .invalidData:
            return "Некорректные данные комнаты"
        case .saveFailed(let error):
            return "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}
