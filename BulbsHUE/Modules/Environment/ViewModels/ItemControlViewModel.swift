//
//  ItemControlViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel для управления отдельной лампой
/// Следует принципам MVVM и SOLID
/// Зависит от абстракций (протоколов), а не от конкретных реализаций
@MainActor
class ItemControlViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Текущая лампа для управления
    @Published var currentLight: Light?
    
    /// Состояние включения/выключения лампы
    @Published var isOn: Bool = false
    
    /// Яркость лампы в процентах (0-100)
    @Published var brightness: Double = 100.0
    
    /// Цвет лампы по умолчанию (тёплый нейтрально-желтоватый ~2700–3000K)
    @Published var defaultWarmColor = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    
    /// Последняя отправленная яркость для предотвращения дублирования запросов
    @Published private var lastSentBrightness: Double = -1
    
    // MARK: - Private Properties
    
    /// Задача для дебаунса изменений яркости
    private var debouncedTask: Task<Void, Never>?
    
    /// Сервис для управления лампами - зависимость от протокола (DIP)
    private let lightControlService: LightControlling
    
    /// Хранение подписок Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Инициализация с внедрением зависимости через протокол
    /// - Parameter lightControlService: Сервис управления лампами
    init(lightControlService: LightControlling) {
        self.lightControlService = lightControlService
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Установить текущую лампу для управления
    /// - Parameter light: Лампа для управления
    func setCurrentLight(_ light: Light) {
        currentLight = light
        
        // Синхронизируем локальное состояние с данными лампы
        isOn = light.on.on
        brightness = light.dimming?.brightness ?? 100.0
    }
    
    /// Переключить состояние включения/выключения лампы
    func togglePower() {
        isOn.toggle()
        sendPowerUpdate(isOn)
    }
    
    /// Установить яркость с дебаунсом (для слайдера)
    /// - Parameter value: Новое значение яркости (0-100)
    func setBrightnessThrottled(_ value: Double) {
        brightness = value
        
        // Отменяем предыдущую задачу дебаунса
        debouncedTask?.cancel()
        
        let roundedValue = round(value)
        
        // Создаём новую задачу с дебаунсом 150мс
        debouncedTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
            } catch {
                return // Task был отменён
            }
            
            guard !Task.isCancelled else { return }
            
            // Коалесценция - отправляем только если изменение >= 1%
            guard let self = self,
                  abs(roundedValue - self.lastSentBrightness) >= 1 else { return }
            
            await self.sendBrightnessUpdate(roundedValue, isThrottled: true)
        }
    }
    
    /// Зафиксировать финальное значение яркости (окончание редактирования слайдера)
    /// - Parameter value: Финальное значение яркости
    func commitBrightness(_ value: Double) {
        debouncedTask?.cancel()
        let roundedValue = round(value)
        brightness = roundedValue
        
        Task { [weak self] in
            await self?.sendBrightnessUpdate(roundedValue, isThrottled: false)
        }
    }
    
    /// Получить название комнаты для текущей лампы
    /// - Returns: Название комнаты или "Без комнаты"
    func getRoomName() -> String {
        guard let light = currentLight else { return "Без комнаты" }
        return lightControlService.getRoomName(for: light)
    }
    
    /// Получить тип лампы для отображения
    /// - Returns: Тип лампы
    func getBulbType() -> String {
        guard let light = currentLight else { return "Unknown" }
        return lightControlService.getBulbType(for: light)
    }
    
    /// Получить иконку для лампы на основе типа комнаты
    /// - Returns: Название изображения иконки
    func getBulbIcon() -> String {
        guard let light = currentLight else { return "f2" }
        return lightControlService.getBulbIcon(for: light)
    }
    
    /// Получить иконку комнаты
    /// - Returns: Название изображения иконки комнаты
    func getRoomIcon() -> String {
        guard let light = currentLight else { return "tr1" }
        return lightControlService.getRoomIcon(for: light)
    }
    
    // MARK: - Private Methods
    
    /// Настройка наблюдателей для синхронизации через протокол
    private func setupObservers() {
        // Очищаем предыдущие подписки
        cancellables.removeAll()
        
        // Подписываемся на изменения списка ламп через протокол
        lightControlService.lightsPublisher
            .sink { [weak self] updatedLights in
                self?.syncWithUpdatedLights(updatedLights)
            }
            .store(in: &cancellables)
    }
    
    /// Синхронизация с обновлённым списком ламп
    /// - Parameter lights: Обновлённый список ламп
    private func syncWithUpdatedLights(_ lights: [Light]) {
        guard let currentLightId = currentLight?.id else { return }
        
        // Находим обновлённую версию текущей лампы
        if let updatedLight = lights.first(where: { $0.id == currentLightId }) {
            // Обновляем текущую лампу
            currentLight = updatedLight
            
            // Синхронизируем состояние только если пользователь не активно взаимодействует
            if debouncedTask == nil {
                isOn = updatedLight.on.on
                brightness = updatedLight.dimming?.brightness ?? brightness
            }
        }
    }
    
    /// Отправить обновление состояния питания
    /// - Parameter powerState: Новое состояние питания
    private func sendPowerUpdate(_ powerState: Bool) {
        guard let light = currentLight else { return }
        
        // Используем протокол для управления лампой
        lightControlService.setPower(for: light, on: powerState)
    }
    
    /// Отправить обновление яркости
    /// - Parameters:
    ///   - value: Новое значение яркости
    ///   - isThrottled: Является ли это промежуточным (throttled) обновлением
    private func sendBrightnessUpdate(_ value: Double, isThrottled: Bool) async {
        guard let light = currentLight else { return }
        
        lastSentBrightness = value
        
        if isThrottled {
            // Для промежуточных значений используем setBrightness
            lightControlService.setBrightness(for: light, brightness: value)
        } else {
            // Для финальных значений используем commitBrightness
            lightControlService.commitBrightness(for: light, brightness: value)
        }
    }
}

// MARK: - Extensions

extension ItemControlViewModel {
    /// Статический метод для создания mock данных (для превью)
    static func createMockViewModel() -> ItemControlViewModel {
        // Создаём mock сервис согласно принципу DIP
        let mockService = LightControlService.createMockService()
        let viewModel = ItemControlViewModel(lightControlService: mockService)
        
        // Создаём mock лампу
        let mockLight = Light(
            id: "mock_light_01",
            type: "light",
            metadata: LightMetadata(name: "Smart Bulb", archetype: nil),
            on: OnState(on: true),
            dimming: Dimming(brightness: 75),
            color: nil,
            color_temperature: nil,
            effects: nil,
            effects_v2: nil,
            mode: nil,
            capabilities: nil,
            color_gamut_type: nil,
            color_gamut: nil,
            gradient: nil
        )
        
        viewModel.setCurrentLight(mockLight)
        return viewModel
    }
}
