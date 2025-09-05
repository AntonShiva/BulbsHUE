//
//  SensorsViewModel.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import Foundation
import Combine
import Observation

/// ViewModel для управления сенсорами
@MainActor
@Observable
class SensorsViewModel {
    
    // MARK: - Published Properties
    
    /// Список всех сенсоров
    var sensors: [HueSensor] = []
    
    /// Флаг загрузки
    var isLoading: Bool = false
    
    /// Текущая ошибка
    var error: Error?
    
    /// Последние события движения
    var motionEvents: [String: Bool] = [:]
    
    /// Последние события кнопок
    var buttonEvents: [String: ButtonEvent] = [:]
    
    // MARK: - Private Properties
    
    private let apiClient: HueAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
        setupEventHandling()
    }
    
    // MARK: - Public Methods
    
    /// Загружает все сенсоры
    func loadSensors() {
        isLoading = true
        error = nil
        
        apiClient.getAllSensors()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] sensors in
                    self?.sensors = sensors
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    /// Настраивает обработку событий в реальном времени
    private func setupEventHandling() {
        // Подписываемся на события от сенсоров
        apiClient.eventPublisher
            .sink { [weak self] event in
                self?.handleSensorEvent(event)
            }
            .store(in: &cancellables)
    }
    
    /// Обрабатывает событие от сенсора
    private func handleSensorEvent(_ event: HueEvent) {
        guard let eventData = event.data else { return }
        
        for data in eventData {
            // Обрабатываем события движения
            if let motion = data.motion {
                motionEvents[data.id ?? ""] = motion.motion
            }
            
            // Обрабатываем события кнопок
            if let button = data.button,
               let event = button.last_event,
               let intValue = Int(event),
               let buttonEvent = ButtonEvent(rawValue: intValue) {
                buttonEvents[data.id ?? ""] = buttonEvent
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Сенсоры движения
    var motionSensors: [HueSensor] {
        sensors.filter { sensor in
            sensor.services?.contains { $0.rtype == "motion" } ?? false
        }
    }
    
    /// Кнопки и переключатели
    var buttonSensors: [HueSensor] {
        sensors.filter { sensor in
            sensor.services?.contains { $0.rtype == "button" } ?? false
        }
    }
    
    /// Датчики температуры
    var temperatureSensors: [HueSensor] {
        sensors.filter { sensor in
            sensor.services?.contains { $0.rtype == "temperature" } ?? false
        }
    }
    
    /// Датчики освещенности
    var lightLevelSensors: [HueSensor] {
        sensors.filter { sensor in
            sensor.services?.contains { $0.rtype == "light_level" } ?? false
        }
    }
}
