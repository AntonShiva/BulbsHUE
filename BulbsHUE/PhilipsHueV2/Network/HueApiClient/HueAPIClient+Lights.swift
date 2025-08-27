//
//  HueAPIClient+Lights.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Lights Endpoints
    
    /// Получает список всех ламп в системе
    /// ИСПРАВЛЕННЫЙ getAllLights - использует только API v2 через HTTPS
    /// - Returns: Combine Publisher со списком ламп
    func getAllLights() -> AnyPublisher<[Light], Error> {
        print("🚀 Используем API v2 через HTTPS...")
        return getAllLightsV2HTTPS()
    }
    
    /// ИСПРАВЛЕННАЯ версия getAllLights для API v2 через HTTPS
    func getAllLightsV2HTTPS() -> AnyPublisher<[Light], Error> {
        print("🚀 Запрос ламп через API v2 HTTPS...")
        
        let endpoint = "/clip/v2/resource/light"
        
        return performRequestHTTPS<LightsResponse>(endpoint: endpoint, method: "GET")
            .flatMap { (response: LightsResponse) -> AnyPublisher<[Light], Error> in
                print("✅ API v2 HTTPS: получено \(response.data.count) ламп")
                
                // Получаем reachable статус через API v1 и объединяем с данными v2
                return self.enrichLightsWithReachableStatus(response.data)
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает информацию о конкретной лампе
    /// - Parameter id: Уникальный идентификатор лампы
    /// - Returns: Combine Publisher с информацией о лампе
    func getLight(id: String) -> AnyPublisher<Light, Error> {
        let endpoint = "/clip/v2/resource/light/\(id)"
        return performRequestHTTPS<LightResponse>(endpoint: endpoint, method: "GET")
            .map { (response: LightResponse) in
                response.data.first ?? Light()
            }
            .eraseToAnyPublisher()
    }
    
    /// ИСПРАВЛЕННЫЙ updateLight - использует только API v2 через HTTPS
    /// - Parameters:
    ///   - id: Уникальный идентификатор лампы
    ///   - state: Новое состояние лампы
    /// - Returns: Combine Publisher с результатом операции
    func updateLight(id: String, state: LightState) -> AnyPublisher<Bool, Error> {
        print("🚀 Управление лампой через API v2 HTTPS...")
        return updateLightV2HTTPS(id: id, state: state)
    }
    
    /// ИСПРАВЛЕННАЯ версия updateLight для API v2 через HTTPS
    func updateLightV2HTTPS(id: String, state: LightState) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            self?.throttleQueue.async {
                guard let self = self else {
                    promise(.failure(HueAPIError.invalidResponse))
                    return
                }
                
                // Ограничение скорости
                let now = Date()
                let timeSinceLastRequest = now.timeIntervalSince(self.lastLightRequestTime)
                
                if timeSinceLastRequest < self.lightRequestInterval {
                    let delay = self.lightRequestInterval - timeSinceLastRequest
                    Thread.sleep(forTimeInterval: delay)
                }
                
                self.lastLightRequestTime = Date()
                
                let endpoint = "/clip/v2/resource/light/\(id)"
                
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(state)
                    
                    print("🔧 API v2 HTTPS команда: PUT \(endpoint)")
                    
                    self.performRequestHTTPS<GenericResponse>(endpoint: endpoint, method: "PUT", body: data)
                        .sink(
                            receiveCompletion: { (completion: Subscribers.Completion<Error>) in
                                if case .failure(let error) = completion {
                                    print("❌ Ошибка обновления лампы API v2: \(error)")
                                    // При ошибке сети считаем лампу недоступной
                                    self.updateLightCommunicationStatus(lightId: id, status: .issues)
                                    promise(.success(false))
                                } else {
                                    print("✅ Лампа успешно обновлена через API v2 HTTPS")
                                    promise(.success(true))
                                }
                            },
                            receiveValue: { (response: GenericResponse) in
                                // Проверяем ошибки связи в ответе
                                self.checkCommunicationErrors(lightId: id, response: response)
                                promise(.success(true))
                            }
                        )
                        .store(in: &self.cancellables)
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Обновляет метаданные лампы (имя, архетип и т.д.) через Hue API v2
    /// - Parameters:
    ///   - id: Уникальный идентификатор лампы
    ///   - metadata: Новые метаданные лампы
    /// - Returns: Combine Publisher с результатом операции
    func updateLightMetadata(id: String, metadata: LightMetadata) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            self?.throttleQueue.async {
                guard let self = self else {
                    promise(.failure(HueAPIError.invalidResponse))
                    return
                }
                
                let endpoint = "/clip/v2/resource/light/\(id)"
                
                // Создаем JSON только с полями, которые поддерживает API
                let metadataUpdate: [String: Any] = [
                    "metadata": [
                        "name": metadata.name
                        // Архетип обычно не изменяется пользователем через API
                    ]
                ]
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: metadataUpdate)
                    
                    print("🔧 API v2 HTTPS обновление метаданных: PUT \(endpoint)")
                    print("📝 Новое имя лампы: \(metadata.name)")
                    
                    self.performRequestHTTPS<GenericResponse>(endpoint: endpoint, method: "PUT", body: jsonData)
                        .sink(
                            receiveCompletion: { (completion: Subscribers.Completion<Error>) in
                                if case .failure(let error) = completion {
                                    print("❌ Ошибка обновления метаданных лампы: \(error)")
                                    promise(.success(false))
                                } else {
                                    print("✅ Метаданные лампы успешно обновлены через API v2")
                                    promise(.success(true))
                                }
                            },
                            receiveValue: { (response: GenericResponse) in
                                promise(.success(true))
                            }
                        )
                        .store(in: &self.cancellables)
                } catch {
                    print("❌ Ошибка сериализации JSON для обновления метаданных: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Мигает лампой для визуального подтверждения (если лампа подключена и включена в сеть)
    /// Использует кратковременное изменение яркости для имитации 1-2 вспышек
    /// - Parameter id: Уникальный идентификатор лампы
    /// - Returns: Combine Publisher с результатом операции
    func blinkLight(id: String) -> AnyPublisher<Bool, Error> {
        print("💡 Отправляем команду мигания для лампы \(id)...")
        
        // Сначала получаем текущее состояние лампы
        return getLight(id: id)
            .flatMap { [weak self] currentLight -> AnyPublisher<Bool, Error> in
                guard let self = self else {
                    return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                let originalBrightness = currentLight.dimming?.brightness ?? 100.0
                let isOn = currentLight.on.on
                
                print("💡 Исходная яркость: \(originalBrightness), включена: \(isOn)")
                
                // Если лампа выключена, включаем её и выключаем обратно
                if !isOn {
                    return self.performOffLightBlink(id: id)
                } else {
                    // Если включена, меняем яркость
                    return self.performBrightnessBlink(id: id, originalBrightness: originalBrightness)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Мигание выключенной лампы (включить-выключить)
    internal func performOffLightBlink(id: String) -> AnyPublisher<Bool, Error> {
        // Быстро включаем
        let turnOnState = LightState(on: OnState(on: true))
        
        return updateLightV2HTTPS(id: id, state: turnOnState)
            .delay(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .flatMap { [weak self] _ -> AnyPublisher<Bool, Error> in
                guard let self = self else {
                    return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                // Быстро выключаем обратно
                let turnOffState = LightState(on: OnState(on: false))
                return self.updateLightV2HTTPS(id: id, state: turnOffState)
            }
            .handleEvents(
                receiveOutput: { success in
                    if success {
                        print("✅ Мигание выключенной лампы \(id) завершено")
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    /// Мигание включенной лампы (изменение яркости)
    internal func performBrightnessBlink(id: String, originalBrightness: Double) -> AnyPublisher<Bool, Error> {
        // Быстро уменьшаем яркость до минимума
        let dimState = LightState(
            dimming: Dimming(brightness: 1.0),
            dynamics: Dynamics(duration: 100) // Быстрый переход
        )
        
        return updateLightV2HTTPS(id: id, state: dimState)
            .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .flatMap { [weak self] _ -> AnyPublisher<Bool, Error> in
                guard let self = self else {
                    return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                // Возвращаем исходную яркость
                let restoreState = LightState(
                    dimming: Dimming(brightness: originalBrightness),
                    dynamics: Dynamics(duration: 100) // Быстрый переход
                )
                return self.updateLightV2HTTPS(id: id, state: restoreState)
            }
            .handleEvents(
                receiveOutput: { success in
                    if success {
                        print("✅ Мигание включенной лампы \(id) завершено")
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    /// Проверяет, мигнула ли лампа (подтверждение сброса)
    internal func checkLightBlink(lightId: String) -> AnyPublisher<Bool, Error> {
        // Сохраняем текущее состояние
        var originalState: Bool = false
        
        return getLight(id: lightId)
            .handleEvents(receiveOutput: { light in
                originalState = light.on.on
            })
            .flatMap { [weak self] light -> AnyPublisher<Bool, Error> in
                guard let self = self else {
                    return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                // Мигаем лампой для подтверждения
                let blinkState = LightState(
                    on: OnState(on: !light.on.on)
                )
                
                return self.updateLightV2HTTPS(id: lightId, state: blinkState)
                    .delay(for: .seconds(0.5), scheduler: RunLoop.main)
                    .flatMap { _ in
                        // Возвращаем в исходное состояние
                        let restoreState = LightState(
                            on: OnState(on: originalState)
                        )
                        return self.updateLightV2HTTPS(id: lightId, state: restoreState)
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+Lights.swift
 
 Описание:
 Расширение HueAPIClient с методами управления лампами.
 
 Основные компоненты:
 - getAllLights - получение списка всех ламп
 - getAllLightsV2HTTPS - получение через API v2 HTTPS
 - getLight - получение информации о лампе
 - updateLight - обновление состояния лампы
 - updateLightV2HTTPS - обновление через API v2 HTTPS
 - blinkLight - мигание лампой
 - performOffLightBlink - мигание выключенной лампы
 - performBrightnessBlink - мигание включенной лампы
 - checkLightBlink - проверка мигания
 
 Зависимости:
 - HueAPIClient базовый класс
 - Light, LightState, OnState, Dimming, Dynamics модели
 - performRequestHTTPS для сетевых запросов
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Networking.swift - сетевые методы
 - HueAPIClient+LightEnrichment.swift - обогащение данных ламп
 */
