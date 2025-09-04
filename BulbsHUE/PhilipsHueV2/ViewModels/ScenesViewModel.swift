//
//  ScenesViewModel.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import Foundation
import Combine

/// ViewModel для управления сценами освещения
@MainActor
class ScenesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Список всех сцен
    @Published var scenes: [HueScene] = []
    
    /// Активная сцена
    @Published var activeSceneId: String?
    
    /// Флаг загрузки
    @Published var isLoading: Bool = false
    
    /// Текущая ошибка
    @Published var error: Error?
    
    /// Режим редактирования сцены
    @Published var isEditingScene: Bool = false
    
    /// Редактируемая сцена
    @Published var editingScene: HueScene?
    
    // MARK: - Private Properties
    
    private let apiClient: HueAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
        setupEventHandling()
    }
    
    // MARK: - Public Methods
    
    /// Загружает все сцены
    func loadScenes() {
        isLoading = true
        error = nil
        
        apiClient.getAllScenes()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] scenes in
                    self?.scenes = scenes
                }
            )
            .store(in: &cancellables)
    }
    
    /// Активирует сцену для группы
    /// - Parameters:
    ///   - scene: Сцена для активации
    ///   - groupId: ID группы (nil для всех ламп)
    func activateScene(_ scene: HueScene, forGroup groupId: String? = nil) {
        activeSceneId = scene.id
        
        // Если группа не указана, активируем для всех ламп сцены
        let targetGroupId = groupId ?? "0"
        
        apiClient.activateScene(sceneId: scene.id)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                        self?.activeSceneId = nil
                    }
                },
                receiveValue: { _ in
                    // Успешно активировано
                }
            )
            .store(in: &cancellables)
    }
    
    /// Создает новую сцену
    /// - Parameters:
    ///   - name: Название сцены
    ///   - lights: Список ID ламп
    ///   - captureCurrentState: Захватить текущее состояние ламп
    func createScene(name: String, lights: [String], captureCurrentState: Bool = true) {
        apiClient.createScene(name: name, lights: lights)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] scene in
                    self?.scenes.append(scene)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Удаляет сцену
    /// - Parameter scene: Сцена для удаления
    func deleteScene(_ scene: HueScene) {
        // Реализация удаления сцены через API
        scenes.removeAll { $0.id == scene.id }
    }
    
    /// Начинает редактирование сцены
    /// - Parameter scene: Сцена для редактирования
    func startEditing(_ scene: HueScene) {
        editingScene = scene
        isEditingScene = true
    }
    
    /// Сохраняет изменения в сцене
    func saveSceneChanges() {
        guard let scene = editingScene else { return }
        
        // Здесь должна быть логика сохранения изменений
        isEditingScene = false
        editingScene = nil
        loadScenes()
    }
    
    /// Отменяет редактирование
    func cancelEditing() {
        isEditingScene = false
        editingScene = nil
    }
    
    // MARK: - Private Methods
    
    /// Настраивает обработку событий
    private func setupEventHandling() {
        // Подписываемся на события изменения сцен
        apiClient.eventPublisher
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }
    
    /// Обрабатывает событие
    private func handleEvent(_ event: HueEvent) {
        guard let eventData = event.data else { return }
        
        for data in eventData {
            if data.type == "scene" {
                // Перезагружаем сцены при изменении
                loadScenes()
                break
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Сцены, сгруппированные по комнатам
    var scenesByRoom: [String: [HueScene]] {
        Dictionary(grouping: scenes) { scene in
            scene.group?.rid ?? "Без комнаты"
        }
    }
    
    /// Динамические сцены
    var dynamicScenes: [HueScene] {
        scenes.filter { $0.speed != nil || $0.auto_dynamic == true }
    }
    
    /// Статические сцены
    var staticScenes: [HueScene] {
        scenes.filter { $0.speed == nil && $0.auto_dynamic != true }
    }
}
