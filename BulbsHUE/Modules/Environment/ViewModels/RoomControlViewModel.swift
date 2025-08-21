//
//  RoomControlViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel для управления отдельной комнатой
/// Аналогично ItemControlViewModel, но для комнат
@MainActor
final class RoomControlViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Текущая комната для управления
    @Published var currentRoom: RoomEntity?
    
    /// Состояние включения/выключения комнаты (всех ламп в ней)
    @Published var isOn: Bool = false
    
    /// Средняя яркость всех ламп в комнате
    @Published var brightness: Double = 100.0
    
    /// Цвет комнаты по умолчанию (тот же что у ламп)
    @Published var defaultWarmColor = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    
    // MARK: - Private Properties
    
    /// Сервис для управления лампами в комнате
    private var lightControlService: LightControlling?
    
    /// Сервис для управления комнатами
    private var roomService: RoomServiceProtocol?
    
    /// Подписки Combine
    private var cancellables = Set<AnyCancellable>()
    
    /// Флаг конфигурации
    private var isConfigured: Bool = false
    
    /// Флаг для предотвращения циклических обновлений во время batch операций
    private var isUpdatingFromBatch: Bool = false
    
    /// Задача для дебаунса изменений яркости
    private var brightnessTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private init() {
        // Пустая инициализация
    }
    
    /// Создать изолированный экземпляр (для SwiftUI StateObject)
    static func createIsolated() -> RoomControlViewModel {
        return RoomControlViewModel()
    }
    
    deinit {
        // Отменяем все активные задачи при деинициализации
        brightnessTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Configuration
    
    /// Конфигурирует ViewModel с сервисами и комнатой
    /// - Parameters:
    ///   - lightControlService: Сервис управления лампами
    ///   - roomService: Сервис управления комнатами
    ///   - room: Комната для управления
    func configure(
        with lightControlService: LightControlling,
        roomService: RoomServiceProtocol,
        room: RoomEntity
    ) {
        self.lightControlService = lightControlService
        self.roomService = roomService
        self.isConfigured = true
        setupObservers()
        setCurrentRoom(room)
    }
    
    // MARK: - Public Methods
    
    /// Установить текущую комнату
    /// - Parameter room: Комната для управления
    func setCurrentRoom(_ room: RoomEntity) {
        self.currentRoom = room
        updateStateFromRoom()
    }
    
    /// Переключить питание всех ламп в комнате
    /// - Parameter newState: Новое состояние
    func setPower(_ newState: Bool) {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return }
        
        // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Предотвращаем обновления состояния во время batch операции
        isUpdatingFromBatch = true
        
        // Сразу устанавливаем UI состояние для responsiveness
        isOn = newState
        
        // Получаем все лампы комнаты
        let roomLights = getRoomLights()
        guard !roomLights.isEmpty else { 
            isUpdatingFromBatch = false
            return 
        }
        
        print("🏠 Переключение комнаты '\(room.name)' -> \(newState ? "ВКЛ" : "ВЫКЛ") (\(roomLights.count) ламп)")
        
        // Групповое управление лампами с ожиданием завершения
        Task { [weak self] in
            // Отправляем команды всем лампам ОДНОВРЕМЕННО, а не по очереди
            await withTaskGroup(of: Void.self) { group in
                for light in roomLights {
                    group.addTask {
                        lightControlService.setPower(for: light, on: newState)
                    }
                }
            }
            
            // Ждем небольшую задержку для получения обновлений от API
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            
            await MainActor.run { [weak self] in
                self?.isUpdatingFromBatch = false
                print("🏠 ✅ Batch операция завершена для комнаты '\(room.name)'")
            }
        }
    }
    
    /// Установить яркость всех ламп в комнате (с дебаунсом)
    /// - Parameter newBrightness: Новая яркость (0-100)
    func setBrightnessThrottled(_ newBrightness: Double) {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return }
        
        // УЛУЧШЕНИЕ: Предотвращаем конфликты при групповом изменении яркости
        isUpdatingFromBatch = true
        
        // Устанавливаем яркость локально для UI responsiveness
        brightness = newBrightness
        
        // Отменяем предыдущую задачу дебаунса
        brightnessTask?.cancel()
        
        // Создаем новую задачу с дебаунсом для плавности
        brightnessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды дебаунс
            
            guard let self = self, !Task.isCancelled else { return }
            
            let roomLights = self.getRoomLights()
            await withTaskGroup(of: Void.self) { group in
                for light in roomLights {
                    group.addTask {
                        lightControlService.setBrightness(for: light, brightness: newBrightness)
                    }
                }
            }
            
            await MainActor.run { [weak self] in
                self?.isUpdatingFromBatch = false
            }
        }
    }
    
    /// Зафиксировать яркость всех ламп в комнате
    /// - Parameter newBrightness: Финальная яркость
    func commitBrightness(_ newBrightness: Double) {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return }
        
        // Отменяем любую pending задачу
        brightnessTask?.cancel()
        isUpdatingFromBatch = true
        
        // Устанавливаем яркость локально
        brightness = newBrightness
        
        print("🏠 💡 Коммит яркости для комнаты '\(room.name)': \(newBrightness)%")
        
        // Групповой коммит яркости
        Task { [weak self] in
            let roomLights = self?.getRoomLights() ?? []
            await withTaskGroup(of: Void.self) { group in
                for light in roomLights {
                    group.addTask {
                        lightControlService.commitBrightness(for: light, brightness: newBrightness)
                    }
                }
            }
            
            // Небольшая задержка для синхронизации
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
            
            await MainActor.run { [weak self] in
                self?.isUpdatingFromBatch = false
                print("🏠 ✅ Коммит яркости завершен для комнаты '\(self?.currentRoom?.name ?? "Unknown")'")
            }
        }
    }
    
    /// Получить название комнаты
    func getRoomName() -> String {
        return currentRoom?.name ?? "Unknown Room"
    }
    
    /// Получить тип комнаты
    func getRoomType() -> String {
        return currentRoom?.type.displayName ?? "Room"
    }
    
    /// Получить иконку комнаты
    func getRoomIcon() -> String {
        return currentRoom?.iconName ?? "room"
    }
    
    /// Проверить доступность комнаты (есть ли доступные лампы)
    func isRoomAvailable() -> Bool {
        let roomLights = getRoomLights()
        return !roomLights.isEmpty && roomLights.contains { $0.isReachable }
    }
    
    /// Получить количество ламп в комнате
    func getLightCount() -> Int {
        return currentRoom?.lightCount ?? 0
    }
    
    // MARK: - Private Methods
    
    /// Настройка наблюдателей
    private func setupObservers() {
        guard let lightControlService = lightControlService else { return }
        
        // Подписываемся на изменения ламп
        lightControlService.lightsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lights in
                self?.updateStateFromLights(lights)
            }
            .store(in: &cancellables)
    }
    
    /// Обновить состояние комнаты на основе ламп
    /// - Parameter lights: Массив всех ламп
    private func updateStateFromLights(_ lights: [Light]) {
        guard let room = currentRoom else { return }
        
        // Игнорируем обновления от API во время batch операций
        guard !isUpdatingFromBatch else { 
            print("🏠 ⏸️ Пропускаем обновление состояния комнаты '\(room.name)' - выполняется batch операция")
            return 
        }
        
        let roomLights = lights.filter { room.lightIds.contains($0.id) }
        updateRoomState(from: roomLights)
    }
    
    /// Обновить состояние из текущей комнаты
    private func updateStateFromRoom() {
        let roomLights = getRoomLights()
        updateRoomState(from: roomLights)
    }
    
    /// Обновить состояние комнаты из массива ламп
    /// - Parameter roomLights: Лампы комнаты
    private func updateRoomState(from roomLights: [Light]) {
        if roomLights.isEmpty {
            isOn = false
            brightness = 0
            return
        }
        
        // Комната "включена" если хотя бы одна лампа включена
        isOn = roomLights.contains { $0.on.on }
        
        // Средняя яркость включенных ламп
        let onLights = roomLights.filter { $0.on.on }
        if !onLights.isEmpty {
            let totalBrightness = onLights.compactMap { $0.dimming?.brightness }.reduce(0, +)
            brightness = Double(totalBrightness) / Double(onLights.count)
        } else {
            brightness = 0
        }
    }
    
    /// Получить лампы комнаты
    /// - Returns: Массив ламп в комнате
    private func getRoomLights() -> [Light] {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return [] }
        
        return lightControlService.lights.filter { room.lightIds.contains($0.id) }
    }
}

// MARK: - Room Service Protocol

/// Протокол для сервиса управления комнатами
protocol RoomServiceProtocol {
    func updateRoom(_ room: RoomEntity) async throws
    func deleteRoom(_ roomId: String) async throws
}

/// Реализация сервиса комнат
final class RoomService: RoomServiceProtocol {
    // TODO: Реализовать методы управления комнатами
    
    func updateRoom(_ room: RoomEntity) async throws {
        print("🏠 Обновление комнаты: \(room.name)")
    }
    
    func deleteRoom(_ roomId: String) async throws {
        print("🏠 Удаление комнаты: \(roomId)")
    }
}
