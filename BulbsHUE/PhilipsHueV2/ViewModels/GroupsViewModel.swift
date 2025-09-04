//
//  GroupsViewModel.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import Foundation
import Combine

/// ViewModel для управления группами (комнатами и зонами)
@MainActor
class GroupsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Список всех групп
    @Published var groups: [HueGroup] = []
    
    /// Флаг загрузки
    @Published var isLoading: Bool = false
    
    /// Текущая ошибка
    @Published var error: Error?
    
    /// Выбранная группа
    @Published var selectedGroup: HueGroup?
    
    // MARK: - Private Properties
    
    private let apiClient: HueAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// Загружает все группы
    func loadGroups() {
        isLoading = true
        error = nil
        
        apiClient.getAllGroups()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] groups in
                    self?.groups = groups
                }
            )
            .store(in: &cancellables)
    }
    
    /// Включает/выключает все лампы в группе
    /// - Parameter group: Группа для переключения
    func toggleGroup(_ group: HueGroup) {
        // Группа 0 не может быть удалена или изменена
        if group.id == "0" {
            // Группа 0 - специальная группа всех ламп
        }
        
        let newState = GroupState(
            on: OnState(on: !(group.on?.on ?? false))
        )
        
        updateGroup(group.id, state: newState)
    }
    
    /// Устанавливает яркость для группы
    /// - Parameters:
    ///   - group: Группа для изменения
    ///   - brightness: Уровень яркости (0-100)
    func setBrightness(for group: HueGroup, brightness: Double) {
        let newState = GroupState(
            dimming: Dimming(brightness: brightness)
        )
        
        updateGroup(group.id, state: newState)
    }
    
    /// Активирует сцену для группы
    /// - Parameters:
    ///   - scene: Сцена для активации
    ///   - group: Группа (если nil, применяется ко всем лампам сцены)
    func activateScene(_ scene: HueScene, for group: HueGroup? = nil) {
        // Для групповой активации сцены используем специальный метод
        if let group = group {
            // Активация сцены для группы
        }
        
        // Здесь должен быть вызов API для активации сцены через группу
    }
    
    /// Включает оповещение для группы
    /// - Parameter group: Группа для оповещения
    func alertGroup(_ group: HueGroup) {
        let newState = GroupState(
            alert: HueAlert(action_values: ["breathe"])
        )
        
        updateGroup(group.id, state: newState)
    }
    
    // MARK: - Private Methods
    
    /// Обновляет состояние группы
    private func updateGroup(_ groupId: String, state: GroupState) {
        apiClient.updateGroup(id: groupId, state: state)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.updateLocalGroup(groupId, with: state)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обновляет локальное состояние группы
    private func updateLocalGroup(_ groupId: String, with state: GroupState) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        
        if let on = state.on {
            groups[index].on = on
        }
        
        if let dimming = state.dimming {
            groups[index].dimming = dimming
        }
    }
    
    // MARK: - Computed Properties
    
    /// Группы по типам
    var rooms: [HueGroup] {
        groups.filter { $0.group_type == "room" }
    }
    
    var zones: [HueGroup] {
        groups.filter { $0.group_type == "zone" }
    }
    
    var lightGroups: [HueGroup] {
        groups.filter { $0.group_type == "light_group" }
    }
    
    var luminaires: [HueGroup] {
        // Luminaire группы создаются автоматически для multi-source ламп
        groups.filter { $0.group_type == "luminaire" }
    }
    
    var lightSources: [HueGroup] {
        // LightSource группы создаются автоматически
        groups.filter { $0.group_type == "light_source" }
    }
}
