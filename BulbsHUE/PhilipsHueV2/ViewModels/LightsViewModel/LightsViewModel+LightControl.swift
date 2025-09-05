//
//  LightsViewModel+LightControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import Foundation
import Combine
import SwiftUI

extension LightsViewModel {
    
    // MARK: - Basic Operations
    
    /// Загружает список всех ламп с обновлением статуса
    func loadLights() {
        guard apiClient.hasValidConnection() else {
            print("⚠️ Нет подключения к мосту - пропускаем загрузку ламп")
            lights = []
            isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        
        print("🚀 Загружаем лампы через API v2 HTTPS с обновлением статуса...")
        
        apiClient.getAllLights()
            .sink(
                receiveCompletion: { [weak self] completion in
                    Task { @MainActor in
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            print("❌ Ошибка загрузки ламп: \(error)")
                            if case HueAPIError.notAuthenticated = error {
                                print("📝 Требуется авторизация - ждем настройки подключения")
                            } else {
                                self?.error = error
                            }
                        }
                    }
                },
                receiveValue: { [weak self] lights in
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        // Добавляем проверку валидности данных
                        guard lights is [Light] else {
                            print("❌ Получены некорректные данные вместо массива ламп")
                            return
                        }
                        
                        print("✅ Загружено \(lights.count) ламп с актуальным статусом")
                        self.lights = lights
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обновляет список ламп с принудительным обновлением статуса reachable
    @MainActor
    func refreshLightsWithStatus() async {
        isLoading = true
        error = nil
        
        print("🔄 Принудительное обновление ламп с проверкой статуса...")
        
        do {
            let updatedLights = try await apiClient.getAllLights()
                .eraseToAnyPublisher()
                .asyncValue()
            
            print("✅ Обновлено \(updatedLights.count) ламп с актуальным статусом")
            self.lights = updatedLights
            
        } catch {
            print("❌ Ошибка обновления ламп: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: - Light Control
    
    /// Включает/выключает лампу
    func toggleLight(_ light: Light) {
        let newState = LightState(
            on: OnState(on: !light.on.on)
        )
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Устанавливает состояние питания (вкл/выкл) явно
    func setPower(for light: Light, on: Bool) {
        let newState = LightState(
            on: OnState(on: on)
        )
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Устанавливает яркость лампы с debouncing
    func setBrightness(for light: Light, brightness: Double) {
        brightnessUpdateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            let newState = LightState(
                dimming: Dimming(brightness: brightness)
            )
            self?.updateLight(light.id, state: newState, currentLight: light)
        }
        
        brightnessUpdateWorkItem = workItem
        
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            workItem.perform()
        }
    }
    
    /// Немедленно устанавливает яркость (для commit после жеста)
    func commitBrightness(for light: Light, brightness: Double) {
        brightnessUpdateWorkItem?.cancel()
        let newState = LightState(
            dimming: Dimming(brightness: brightness)
        )
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Устанавливает цвет лампы с debouncing
    func setColor(for light: Light, color: SwiftUI.Color) {
        colorUpdateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            let xyColor = self?.convertToXY(color: color, gamutType: light.color_gamut_type) ?? XYColor(x: 0.3, y: 0.3)
            let newState = LightState(
                color: HueColor(xy: xyColor)
            )
            self?.updateLight(light.id, state: newState, currentLight: light)
        }
        
        colorUpdateWorkItem = workItem
        
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            workItem.perform()
        }
    }
    
    /// Устанавливает цвет лампы немедленно без debouncing (для пресетов)
    func setColorImmediate(for light: Light, color: SwiftUI.Color) {
        let xyColor = convertToXY(color: color, gamutType: light.color_gamut_type)
        let newState = LightState(
            color: HueColor(xy: xyColor)
        )
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Устанавливает цветовую температуру
    func setColorTemperature(for light: Light, temperature: Int) {
        let mirek = 1_000_000 / temperature
        let newState = LightState(
            color_temperature: ColorTemperature(mirek: mirek)
        )
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Применяет эффект к лампе
    func applyEffect(to light: Light, effect: String) {
        let newState = LightState(
            effects_v2: EffectsV2(effect: effect)
        )
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Обновляет несколько ламп одновременно
    func updateMultipleLights(_ lights: [Light], state: LightState) {
        if lights.count > 3 {
            print("Предупреждение: Для синхронного изменения более 3 ламп используйте группы")
        }
        
        for light in lights {
            updateLight(light.id, state: state, currentLight: light)
        }
    }
    
    /// Включает режим оповещения (мигание)
    func alertLight(_ light: Light) {
        applyEffect(to: light, effect: "breathe")
    }
    
    /// Мигает лампой для визуального подтверждения
    func blinkLight(_ light: Light) {
        apiClient.blinkLight(id: light.id)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Ошибка мигания лампы \(light.metadata.name): \(error)")
                    }
                },
                receiveValue: { success in
                    if success {
                        print("✅ Лампа \(light.metadata.name) мигнула успешно")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Переименовывает лампу
    func renameLight(_ light: Light, newName: String) {
        var updatedMetadata = light.metadata
        updatedMetadata.name = newName
        
        updateLocalLight(light.id, with: LightState())
        
        if let index = lights.firstIndex(where: { $0.id == light.id }) {
            lights[index].metadata.name = newName
        }
    }
    
    /// Перемещает лампу в комнату
    func moveToRoom(_ light: Light, roomId: String) {
        if let index = lights.firstIndex(where: { $0.id == light.id }) {
            lights[index].metadata.archetype = roomId
        }
    }
    
    /// Обновляет статус связи конкретной лампы
    func updateLightCommunicationStatus(lightId: String, status: CommunicationStatus) {
        guard let index = lights.firstIndex(where: { $0.id == lightId }) else {
            print("⚠️ LightsViewModel: Лампа с ID \(lightId) не найдена для обновления статуса")
            return
        }
        
        lights[index].communicationStatus = status
        print("✅ LightsViewModel: Обновлен статус связи лампы \(lightId): \(status)")
        objectWillChange.send()
    }
    
    // MARK: - Private Update Method
    
    /// Обновляет состояние лампы через API
    private func updateLight(_ lightId: String, state: LightState, currentLight: Light? = nil) {
        guard activeRequests < maxActiveRequests else {
            print("⚠️ Слишком много активных запросов. Подождите.")
            return
        }
        
        activeRequests += 1
        let optimizedState = state.optimizedState(currentLight: currentLight)
        
        print("🚀 Обновляем лампу \(lightId) через API v2 HTTPS...")
        
        apiClient.updateLight(id: lightId, state: optimizedState)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.activeRequests -= 1
                    
                    if case .failure(let error) = completion {
                        self?.error = error
                        print("❌ Не удалось обновить лампу \(lightId): \(error)")
                        
                        switch error {
                        case HueAPIError.rateLimitExceeded:
                            print("⚠️ Превышен лимит запросов")
                        case HueAPIError.bufferFull:
                            print("⚠️ Буфер моста переполнен")
                        case HueAPIError.notAuthenticated:
                            print("🔐 Проблема с авторизацией")
                        default:
                            break
                        }
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        print("✅ Лампа \(lightId) успешно обновлена")
                        self?.updateLocalLight(lightId, with: optimizedState)
                    } else {
                        print("❌ Не удалось обновить лампу \(lightId)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Color Conversion
    
    /// Конвертирует SwiftUI Color в XY координаты
    private func convertToXY(color: SwiftUI.Color, gamutType: String? = nil) -> XYColor {
        return ColorConversion.convertToXY(color: color, gamutType: gamutType)
    }
    
    /// Конвертирует XY в RGB для UI
    func convertXYToColor(_ xy: XYColor, brightness: Double = 1.0, gamutType: String? = nil) -> Color {
        return ColorConversion.convertXYToColor(xy, brightness: brightness, gamutType: gamutType)
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ LightsViewModel+LightControl.swift
 
 Описание:
 Расширение LightsViewModel для управления состоянием ламп.
 Содержит методы включения/выключения, изменения яркости, цвета и эффектов.
 
 Основные компоненты:
 - Загрузка и обновление списка ламп
 - Управление питанием (on/off)
 - Управление яркостью с debouncing
 - Управление цветом и цветовой температурой
 - Применение эффектов
 - Переименование и перемещение ламп
 
 Использование:
 viewModel.toggleLight(light)
 viewModel.setBrightness(for: light, brightness: 75)
 viewModel.setColor(for: light, color: .blue)
 
 Зависимости:
 - Использует internal свойства из основного класса
 - Требует HueAPIClient для отправки команд
 - ColorConversion для работы с цветом
 */
