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
    
    // MARK: - Initialization
    
    private init() {
        // Пустая инициализация
    }
    
    /// Создать изолированный экземпляр (для SwiftUI StateObject)
    static func createIsolated() -> RoomControlViewModel {
        return RoomControlViewModel()
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
        
        isOn = newState
        
        // Получаем все лампы комнаты и управляем ими
        let roomLights = getRoomLights()
        for light in roomLights {
            lightControlService.setPower(for: light, on: newState)
        }
    }
    
    /// Установить яркость всех ламп в комнате
    /// - Parameter newBrightness: Новая яркость (0-100)
    func setBrightnessThrottled(_ newBrightness: Double) {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return }
        
        brightness = newBrightness
        
        // Устанавливаем яркость для всех ламп в комнате
        let roomLights = getRoomLights()
        for light in roomLights {
            lightControlService.setBrightness(for: light, brightness: newBrightness)
        }
    }
    
    /// Зафиксировать яркость всех ламп в комнате
    /// - Parameter newBrightness: Финальная яркость
    func commitBrightness(_ newBrightness: Double) {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return }
        
        brightness = newBrightness
        
        // Коммитим яркость для всех ламп в комнате
        let roomLights = getRoomLights()
        for light in roomLights {
            lightControlService.commitBrightness(for: light, brightness: newBrightness)
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
