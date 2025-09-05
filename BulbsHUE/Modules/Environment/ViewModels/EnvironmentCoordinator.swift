//
//  EnvironmentCoordinator.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import Foundation
import Combine
import Observation
import SwiftUI

/// Координатор для управления взаимодействием ламп и комнат в Environment
/// Следует принципам SOLID - координирует отдельные ViewModels, не делая их работу
@MainActor
@Observable
class EnvironmentCoordinator  {
    // MARK: - Child ViewModels
    
    /// ViewModel для управления лампами
    var lightsViewModel: EnvironmentLightsViewModel
    
    /// ViewModel для управления комнатами
    var roomsViewModel: RoomsViewModel
    
    // MARK: - Computed Properties для удобства
    
    /// Есть ли назначенные лампы (делегируем в lights ViewModel)
    var hasAssignedLights: Bool {
        lightsViewModel.hasAssignedLights
    }
    
    /// Есть ли созданные комнаты (делегируем в rooms ViewModel)
    var hasRooms: Bool {
        roomsViewModel.hasRooms
    }
    
    /// Количество ламп (делегируем в lights ViewModel)
    var assignedLightsCount: Int {
        lightsViewModel.assignedLightsCount
    }
    
    /// Количество комнат (делегируем в rooms ViewModel)
    var roomsCount: Int {
        roomsViewModel.roomsCount
    }
    
    // MARK: - Initialization
    
    /// Инициализация с внедрением готовых ViewModels
    /// - Parameters:
    ///   - lightsViewModel: ViewModel для ламп
    ///   - roomsViewModel: ViewModel для комнат
    init(
        lightsViewModel: EnvironmentLightsViewModel,
        roomsViewModel: RoomsViewModel
    ) {
        self.lightsViewModel = lightsViewModel
        self.roomsViewModel = roomsViewModel
    }
    
    // MARK: - Coordination Methods
    
    /// Обновить все данные (координирует обновление и ламп, и комнат)
    func refreshAll() {
        lightsViewModel.refreshLights()
        roomsViewModel.refreshRooms()
    }
    
    /// Принудительная синхронизация состояния (только для ламп)
    func forceStateSync() {
        lightsViewModel.forceStateSync()
    }
    
    /// Удаление лампы из комнаты и Environment
    /// - Parameter lightId: ID лампы
    func removeLightFromEnvironment(_ lightId: String) {
        // TODO: Здесь можно добавить логику удаления лампы из всех комнат
        // перед удалением из Environment
        
        lightsViewModel.removeLightFromEnvironment(lightId)
        
        // Обновляем комнаты, если лампа была в какой-то комнате
        roomsViewModel.refreshRooms()
    }
    
    /// Удаление комнаты
    /// - Parameter roomId: ID комнаты
    func removeRoom(_ roomId: String) {
        roomsViewModel.removeRoom(roomId)
        
        // TODO: Здесь можно добавить логику для обновления статуса ламп,
        // которые были в удаленной комнате
    }
    
    /// Проверить, в какой комнате находится лампа
    /// - Parameter lightId: ID лампы
    /// - Returns: Комната, в которой находится лампа, или nil
    func findRoomForLight(_ lightId: String) -> RoomEntity? {
        return roomsViewModel.rooms.first { room in
            room.lightIds.contains(lightId)
        }
    }
    
    /// Получить лампы для определенной комнаты
    /// - Parameter roomId: ID комнаты
    /// - Returns: Массив ламп в комнате
    func getLightsForRoom(_ roomId: String) -> [Light] {
        guard let room = roomsViewModel.rooms.first(where: { $0.id == roomId }) else {
            return []
        }
        
        return lightsViewModel.assignedLights.filter { light in
            room.lightIds.contains(light.id)
        }
    }
}

// MARK: - Factory для создания

extension EnvironmentCoordinator {
    /// Создать координатор с настроенными зависимостями
    /// - Parameters:
    ///   - appViewModel: Основной ViewModel приложения
    ///   - dataPersistenceService: Сервис персистентных данных
    ///   - diContainer: DI контейнер для Use Cases
    /// - Returns: Настроенный координатор
    static func create(
        appViewModel: AppViewModel,
        dataPersistenceService: DataPersistenceService,
        diContainer: DIContainer
    ) -> EnvironmentCoordinator {
        
        // Создаем ViewModel для ламп
        let lightsViewModel = EnvironmentLightsViewModel(
            appViewModel: appViewModel,
            dataPersistenceService: dataPersistenceService
        )
        
        // Создаем ViewModel для комнат
        let roomsViewModel = RoomsViewModel(
            getRoomsUseCase: diContainer.getRoomsUseCase,
            deleteRoomUseCase: diContainer.deleteRoomUseCase,
            roomRepository: diContainer.roomRepository
        )
        
        // Создаем координатор
        return EnvironmentCoordinator(
            lightsViewModel: lightsViewModel,
            roomsViewModel: roomsViewModel
        )
    }
    
    /// Создать mock координатор для превью
    static func createMock() -> EnvironmentCoordinator {
        return EnvironmentCoordinator(
            lightsViewModel: EnvironmentLightsViewModel.createMock(),
            roomsViewModel: RoomsViewModel.createMock()
        )
    }
}
