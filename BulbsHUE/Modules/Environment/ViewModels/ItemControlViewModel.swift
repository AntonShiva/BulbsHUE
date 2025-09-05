//
//  ItemControlViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import Foundation
import SwiftUI
import Combine
import Observation

/// ViewModel для управления отдельной лампой
/// Следует принципам MVVM и SOLID
/// Зависит от абстракций (протоколов), а не от конкретных реализаций
/// Каждый экземпляр изолирован для работы с одной лампой
@MainActor
@Observable
class ItemControlViewModel  {
    // MARK: - Published Properties
    
    /// Текущая лампа для управления
    var currentLight: Light?
    
    /// Состояние включения/выключения лампы
    var isOn: Bool = false
    
    /// Яркость лампы в процентах (0-100)
    var brightness: Double = 100.0
    
    /// Цвет лампы по умолчанию (тёплый нейтрально-желтоватый ~2700–3000K)
    var defaultWarmColor = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    
    /// Динамический цвет лампы на основе установленного пользователем цвета
    var dynamicColor: Color = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    
    /// Последняя отправленная яркость для предотвращения дублирования запросов
    private var lastSentBrightness: Double = -1
    
    /// Запомненная яркость для восстановления при включении лампы
    private var rememberedBrightness: Double = 100.0
    
    // MARK: - Private Properties
    
    /// Задача для дебаунса изменений яркости
    private var debouncedTask: Task<Void, Never>?
    
    /// Сервис для управления лампами - зависимость от протокола (DIP)
    private var lightControlService: LightControlling?
    
    /// Хранение подписок Combine
    private var cancellables = Set<AnyCancellable>()
    
    /// Флаг для отслеживания конфигурации
    private var isConfigured: Bool = false
    
    // MARK: - Initialization
    
    /// Приватный инициализатор - используйте статические методы для создания
    init() {
        // Пустая инициализация - будет сконфигурирована позже
    }
    
    /// Инициализация с внедрением зависимости через протокол
    /// - Parameter lightControlService: Сервис управления лампами
    init(lightControlService: LightControlling) {
        self.lightControlService = lightControlService
        self.isConfigured = true
        setupObservers()
    }
    
    // MARK: - Configuration
    
    /// Конфигурирует ViewModel с сервисом и лампой
    /// - Parameters:
    ///   - lightControlService: Сервис управления лампами
    ///   - light: Лампа для управления
    func configure(with lightControlService: LightControlling, light: Light) {
        self.lightControlService = lightControlService
        self.isConfigured = true
        setupObservers()
        setCurrentLight(light)
    }
    
    // MARK: - Public Methods
    
    /// Установить текущую лампу для управления
    /// - Parameter light: Лампа для управления
    func setCurrentLight(_ light: Light) {
        guard isConfigured else {
            return
        }
        
        currentLight = light
        
        // Обновляем динамический цвет из LightColorStateService
        updateDynamicColor()
        
        // Получаем реальное состояние лампы с учетом доступности
        let effectiveState = light.effectiveStateWithBrightness
        let isReachable = light.isReachable
        
        // СИНХРОНИЗАЦИЯ ЛОГИКА с учетом реальной доступности:
        if !isReachable {
            // Лампа недоступна (выключена из сети) - показываем как выключенную
            isOn = false
            brightness = 0.0
        } else if !effectiveState.isOn {
            // Лампа доступна, но выключена программно
            isOn = false
            brightness = 0.0
            // Запоминаем последнюю яркость если она была больше 0
            if effectiveState.brightness > 0 {
                rememberedBrightness = effectiveState.brightness
            }
        } else {
            // Лампа включена и доступна
            isOn = true
            // Если API показывает яркость 0 при включенной лампе - показываем минимум 1%
            let currentBrightness = effectiveState.brightness > 0 ? effectiveState.brightness : 1.0
            brightness = currentBrightness
            // Обновляем запомненную яркость
            rememberedBrightness = currentBrightness
        }
        
        // @Observable handles UI updates automatically
    }
    
    /// Переключить состояние включения/выключения лампы
    func togglePower() {
        guard isConfigured else { return }
        let newState = !isOn
        
        // Используем setPower для корректной синхронизации
        setPower(newState)
    }
    
    /// Установить состояние питания лампы
    /// - Parameter powerState: Новое состояние питания (true - включено, false - выключено)
    func setPower(_ powerState: Bool) {
        guard isConfigured else { return }
        
        if powerState {
            // Включаем лампу
            isOn = true
            // Восстанавливаем запомненную яркость или устанавливаем минимум 1%
            let targetBrightness = rememberedBrightness > 0 ? rememberedBrightness : 1.0
            brightness = targetBrightness
        } else {
            // Выключаем лампу - запоминаем текущую яркость если она больше 0
            if brightness > 0 {
                rememberedBrightness = brightness
            }
            isOn = false
            brightness = 0.0
        }
        
        sendPowerUpdate(powerState)
    }
    
    /// Установить яркость с дебаунсом (для слайдера)
    /// - Parameter value: Новое значение яркости (0-100)
    func setBrightnessThrottled(_ value: Double) {
        guard isConfigured else { return }
        
        brightness = value
        
        // СИНХРОНИЗАЦИЯ: Если яркость увеличивается при выключенной лампе - включаем лампу
        if value > 0 && !isOn {
            isOn = true
            rememberedBrightness = value // Запоминаем новую яркость
            sendPowerUpdate(true)
        }
        // СИНХРОНИЗАЦИЯ: Если яркость = 0 и лампа включена - выключаем лампу
        else if value == 0 && isOn {
            // Запоминаем предыдущую яркость перед выключением
            if brightness > 0 {
                rememberedBrightness = brightness
            }
            isOn = false
            sendPowerUpdate(false)
        }
        // Обновляем запомненную яркость при изменении (если лампа включена)
        else if value > 0 && isOn {
            rememberedBrightness = value
        }
        
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
        guard isConfigured else { return }
        
        debouncedTask?.cancel()
        let roundedValue = round(value)
        brightness = roundedValue
        
        // СИНХРОНИЗАЦИЯ: Если яркость увеличивается при выключенной лампе - включаем лампу
        if roundedValue > 0 && !isOn {
            isOn = true
            rememberedBrightness = roundedValue
            sendPowerUpdate(true)
        }
        // СИНХРОНИЗАЦИЯ: Если яркость = 0 и лампа включена - выключаем лампу
        else if roundedValue == 0 && isOn {
            // Запоминаем предыдущую яркость перед выключением
            if brightness > 0 {
                rememberedBrightness = brightness
            }
            isOn = false
            sendPowerUpdate(false)
        }
        // Обновляем запомненную яркость при изменении (если лампа включена)
        else if roundedValue > 0 && isOn {
            rememberedBrightness = roundedValue
        }
        
        Task { [weak self] in
            await self?.sendBrightnessUpdate(roundedValue, isThrottled: false)
        }
    }
    
    /// Получить название комнаты для текущей лампы
    /// - Returns: Название комнаты или "Без комнаты"
    func getRoomName() -> String {
        guard let light = currentLight, let service = lightControlService else { 
            return "Без комнаты" 
        }
        return service.getRoomName(for: light)
    }
    
    /// Получить тип лампы для отображения
    /// - Returns: Тип лампы
    func getBulbType() -> String {
        guard let light = currentLight, let service = lightControlService else { 
            return "Unknown" 
        }
        return service.getBulbType(for: light)
    }
    
    /// Получить иконку для лампы на основе типа комнаты
    /// - Returns: Название изображения иконки
    func getBulbIcon() -> String {
        guard let light = currentLight, let service = lightControlService else { 
            return "f2" 
        }
        return service.getBulbIcon(for: light)
    }
    
    /// Получить иконку комнаты
    /// - Returns: Название изображения иконки комнаты
    func getRoomIcon() -> String {
        guard let light = currentLight, let service = lightControlService else { 
            return "tr1" 
        }
        return service.getRoomIcon(for: light)
    }
    
    /// Проверить доступность лампы по сети
    /// - Returns: true если лампа доступна, false если недоступна (обесточена)
    func isLightReachable() -> Bool {
        guard let light = currentLight else { 
            return false 
        }
        return light.isReachable
    }
    
    /// Обновить динамический цвет лампы
    private func updateDynamicColor() {
        guard let light = currentLight else { return }
        
        // Получаем цвет из LightColorStateService
        dynamicColor = LightColorStateService.shared.getBaseColor(for: light)
    }
    
    // MARK: - Private Methods
    
    /// Настройка наблюдателей для синхронизации через протокол
    private func setupObservers() {
        guard let lightControlService = lightControlService else { return }
        
        // Очищаем предыдущие подписки
        cancellables.removeAll()
        
        // Подписываемся на изменения списка ламп через протокол
        lightControlService.lightsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] updatedLights in
                self?.syncWithUpdatedLights(updatedLights)
            }
            .store(in: &cancellables)
        
        // @Observable не поддерживает publishers - синхронизация через прямое обращение
        // NavigationManager.shared.$selectedLightForMenu больше недоступно
        // Используем прямое обращение к NavigationManager.shared.selectedLightForMenu при необходимости
    }
    
    /// Обработка обновления лампы из NavigationManager
    /// - Parameter updatedLight: Обновленная лампа из NavigationManager
    private func handleNavigationManagerLightUpdate(_ updatedLight: Light?) {
        guard let updatedLight = updatedLight,
              let currentLight = currentLight,
              currentLight.id == updatedLight.id else {
            return
        }
        
        // Обновляем текущую лампу с новыми данными
        self.currentLight = updatedLight
        print("✅ ItemControlViewModel: Обновлена лампа из NavigationManager: \(updatedLight.metadata.name)")
    }
    
    /// Синхронизация с обновлённым списком ламп
    /// - Parameter lights: Обновлённый список ламп
    private func syncWithUpdatedLights(_ lights: [Light]) {
        guard let currentLightId = currentLight?.id else { return }
        
        // Находим обновлённую версию текущей лампы
        if let updatedLight = lights.first(where: { $0.id == currentLightId }) {
            let wasReachable = currentLight?.isReachable ?? true
            let isNowReachable = updatedLight.isReachable
            
            // ✅ Сохраняем пользовательские поля (UI) при обновлениях из API
            let preservedUserSubtype = currentLight?.metadata.userSubtypeName
            let preservedUserIcon = currentLight?.metadata.userSubtypeIcon
            var mergedLight = updatedLight
            if (mergedLight.metadata.userSubtypeName ?? "").isEmpty {
                mergedLight.metadata.userSubtypeName = preservedUserSubtype
            }
            if (mergedLight.metadata.userSubtypeIcon ?? "").isEmpty {
                mergedLight.metadata.userSubtypeIcon = preservedUserIcon
            }
            
            // Обновляем текущую лампу объединённой версией
            currentLight = mergedLight
            
            // Обновляем динамический цвет при изменениях
            updateDynamicColor()
            
            // Если изменился статус связи - принудительно обновляем UI
            if wasReachable != isNowReachable {
                // @Observable handles UI updates automatically
            }
            
            // ИСПРАВЛЕНИЕ: Синхронизируем состояние ВСЕГДА при обновлении от API (не только когда пользователь не взаимодействует)
            // Это важно для корректного отображения состояния при переключении вкладок
            let effectiveState = mergedLight.effectiveStateWithBrightness
            let isReachable = mergedLight.isReachable
            
            if !isReachable {
                // Лампа недоступна - показываем как выключенную
                isOn = false
                brightness = 0.0
            } else if !effectiveState.isOn {
                // Лампа выключена - показываем 0, но запоминаем яркость если она есть
                isOn = false
                brightness = 0.0
                if effectiveState.brightness > 0 {
                    rememberedBrightness = effectiveState.brightness
                }
            } else {
                // Лампа включена - показываем актуальную яркость и запоминаем её
                isOn = true
                let currentBrightness = effectiveState.brightness > 0 ? effectiveState.brightness : 1.0
                brightness = currentBrightness
                rememberedBrightness = currentBrightness
            }
            
            // @Observable handles UI updates automatically
        }
    }
    
    /// Отправить обновление состояния питания
    /// - Parameter powerState: Новое состояние питания
    private func sendPowerUpdate(_ powerState: Bool) {
        guard let light = currentLight, let service = lightControlService else { return }
        
        // Используем протокол для управления лампой
        service.setPower(for: light, on: powerState)
    }
    
    /// Отправить обновление яркости
    /// - Parameters:
    ///   - value: Новое значение яркости
    ///   - isThrottled: Является ли это промежуточным (throttled) обновлением
    private func sendBrightnessUpdate(_ value: Double, isThrottled: Bool) async {
        guard let light = currentLight, let service = lightControlService else { return }
        
        lastSentBrightness = value
        
        if isThrottled {
            // Для промежуточных значений используем setBrightness
            service.setBrightness(for: light, brightness: value)
        } else {
            // Для финальных значений используем commitBrightness
            service.commitBrightness(for: light, brightness: value)
        }
    }
}

// MARK: - Extensions

extension ItemControlViewModel {
    /// Создать изолированную ViewModel без конфигурации
    /// Используется для @StateObject инициализации
    static func createIsolated() -> ItemControlViewModel {
        return ItemControlViewModel()
    }
    
    /// Создать полностью сконфигурированную ViewModel
    /// - Parameter lightControlService: Сервис управления лампами
    /// - Returns: Сконфигурированная ViewModel
    static func createConfigured(with lightControlService: LightControlling) -> ItemControlViewModel {
        return ItemControlViewModel(lightControlService: lightControlService)
    }
    
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

// MARK: - Extensions
