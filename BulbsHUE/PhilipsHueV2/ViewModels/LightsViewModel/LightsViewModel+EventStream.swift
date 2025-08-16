//
//  LightsViewModel+EventStream.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//


import Foundation
import Combine

extension LightsViewModel {
    
    // MARK: - Event Stream Management
    
    /// Запускает мониторинг изменений состояния ламп в реальном времени
    func startLightStatusMonitoring() {
        print("🔄 Запускаем мониторинг статуса ламп в реальном времени...")
        setupEventStreamSubscription()
    }
    
    /// Останавливает мониторинг изменений состояния ламп
    func stopLightStatusMonitoring() {
        print("⏹️ Останавливаем мониторинг статуса ламп...")
        apiClient.disconnectEventStream()
    }
    
    /// Запускает подписку на события (рекомендуемый подход)
    func startEventStream() {
        stopAutoRefresh()
        
        eventStreamCancellable = apiClient.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleLightEvent(event)
            }
        
        apiClient.connectToEventStream()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Event stream error: \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    /// Останавливает поток событий
    func stopEventStream() {
        eventStreamCancellable?.cancel()
        apiClient.disconnectEventStream()
    }
    
    /// Запускает автоматическое обновление (устаревший метод)
    func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.loadLights()
        }
    }
    
    /// Останавливает автоматическое обновление
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Private Methods
    
    /// Настраивает подписку на Event Stream
    private func setupEventStreamSubscription() {
        print("🔄 Настраиваем подписку на Event Stream для реального времени...")
        
        apiClient.connectToEventStreamV2()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("❌ Ошибка Event Stream: \(error.localizedDescription)")
                    case .finished:
                        print("🔄 Event Stream завершен")
                    }
                },
                receiveValue: { [weak self] event in
                    print("📡 Получено событие от Event Stream: \(event)")
                    self?.handleLightEvent(event)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обрабатывает события изменения состояния ламп
    private func handleLightEvent(_ event: HueEvent) {
        print("🔄 Обрабатываем событие лампы...")
        
        guard let eventData = event.data else {
            print("⚠️ Событие без данных")
            return
        }
        
        for data in eventData {
            print("📊 Тип события: \(String(describing: data.type)), ID: \(data.id ?? "unknown")")
            
            if data.type == "light", let lightId = data.id {
                print("💡 Обновляем лампу с ID: \(lightId)")
                updateLightFromEvent(lightId: lightId, eventData: data)
            }
        }
    }
    
    /// Обновляет локальное состояние лампы на основе события
    private func updateLightFromEvent(lightId: String, eventData: EventData) {
        guard let index = lights.firstIndex(where: { $0.id == lightId }) else {
            print("⚠️ Лампа с ID \(lightId) не найдена в локальном списке")
            return
        }
        
        print("🔄 Обновляем лампу \(lights[index].metadata.name)...")
        
        var isUpdated = false
        
        if let on = eventData.on {
            let currentOn = lights[index].on.on
            if currentOn != on.on {
                lights[index].on = on
                isUpdated = true
                print("   ⚡ Изменено состояние: \(on.on ? "включена" : "выключена")")
            }
        }
        
        if let dimming = eventData.dimming {
            if lights[index].dimming?.brightness != dimming.brightness {
                lights[index].dimming = dimming
                isUpdated = true
                print("   🔆 Изменена яркость: \(dimming.brightness)%")
            }
        }
        
        if let color = eventData.color {
            lights[index].color = color
            isUpdated = true
            print("   🎨 Изменен цвет")
        }
        
        if let colorTemp = eventData.color_temperature {
            lights[index].color_temperature = colorTemp
            isUpdated = true
            print("   🌡️ Изменена цветовая температура")
        }
        
        if isUpdated {
            print("🔄 Обновляем статус reachable для лампы \(lightId)...")
            Task {
                await updateLightReachableStatus(lightId: lightId)
            }
        }
    }
    
    /// Обновляет статус reachable для конкретной лампы
    @MainActor
    private func updateLightReachableStatus(lightId: String) async {
        do {
            let lightsV1 = try await apiClient.getLightsV1WithReachableStatus()
                .eraseToAnyPublisher()
                .asyncValue()
            
            if let index = lights.firstIndex(where: { $0.id == lightId }),
               let lightV1 = apiClient.findMatchingV1Light(v2Light: lights[index], v1Lights: lightsV1) {
                
                let wasReachable = lights[index].isReachable
                let newReachable = lightV1.state?.reachable ?? false
                
                if wasReachable != newReachable {
                    lights[index].communicationStatus = newReachable ? .online : .offline
                    print("   📡 Обновлен статус reachable: \(newReachable ? "доступна" : "недоступна")")
                } else {
                    print("   📡 Статус reachable не изменился: \(newReachable ? "доступна" : "недоступна")")
                }
            }
        } catch {
            print("❌ Ошибка обновления статуса reachable: \(error.localizedDescription)")
        }
    }
    
    /// Ищет добавленную лампу после сброса
    private func searchForAddedLight(_ serialNumber: String) {
        print("🔍 Ищем добавленную лампу \(serialNumber) в обновленном списке...")
        isLoading = false
    }
}

// MARK: - Async/Await Extensions

extension AnyPublisher {
    /// Преобразует Publisher в async/await
    func asyncValue() async throws -> Output {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ LightsViewModel+EventStream.swift
 
 Описание:
 Расширение LightsViewModel для работы с Server-Sent Events (SSE).
 Обеспечивает мониторинг изменений состояния ламп в реальном времени.
 
 Основные компоненты:
 - Управление подпиской на Event Stream
 - Обработка событий изменения состояния
 - Обновление статуса reachable
 - Альтернативный метод через Timer (устаревший)
 - Async/await утилиты
 
 Использование:
 viewModel.startEventStream()
 viewModel.stopEventStream()
 viewModel.startLightStatusMonitoring()
 
 Зависимости:
 - Использует internal свойства из основного класса
 - Требует HueAPIClient для подключения к SSE
 - Async/await для современных операций
 */
