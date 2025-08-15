//
//  HueAPIClient+LightDiscovery.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Modern Light Discovery
    
    /// Современный метод добавления ламп (гибрид v1/v2)
    func addLightModern(serialNumber: String? = nil) -> AnyPublisher<[Light], Error> {
        // Для обычного поиска используем чистый API v2
        if serialNumber == nil {
            return discoverLightsV2()
        }
        
        // Для серийного номера - минимальное использование v1
        guard let serial = serialNumber, isValidSerialNumber(serial) else {
            return Fail(error: HueAPIError.unknown("Неверный формат серийного номера"))
                .eraseToAnyPublisher()
        }
        
        print("🔍 Запуск поиска лампы по серийному номеру: \(serial)")
        
        // Шаг 1: Инициация поиска через v1 (единственный v1 вызов)
        return initiateSearchV1(serial: serial)
            .flatMap { _ in
                // Шаг 2: Ждем 40 секунд согласно спецификации
                print("⏱ Ожидание завершения поиска (40 сек)...")
                return Just(())
                    .delay(for: .seconds(40), scheduler: RunLoop.main)
                    .eraseToAnyPublisher()
            }
            .flatMap { _ in
                // Шаг 3: Получаем результаты через API v2
                print("📡 Получение результатов через API v2...")
                return self.getAllLightsV2HTTPS()
            }
            .map { lights in
                // Шаг 4: Фильтруем новые лампы
                return lights.filter { light in
                    light.isNewLight || light.metadata.name.contains("Hue")
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Добавляет лампу по серийному номеру через правильный API flow
    func addLightBySerialNumber(_ serialNumber: String) -> AnyPublisher<[Light], Error> {
        let cleanSerial = serialNumber.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        print("🔍 Добавление лампы по серийному номеру: \(cleanSerial)")
        
        // Сохраняем текущие ID ламп для сравнения
        var existingLightIds = Set<String>()
        
        return getAllLightsV2HTTPS()
            .handleEvents(receiveOutput: { lights in
                // Сохраняем ID существующих ламп
                existingLightIds = Set(lights.map { $0.id })
                print("📝 Текущие лампы: \(existingLightIds.count)")
            })
            .flatMap { [weak self] _ -> AnyPublisher<[Light], Error> in
                guard let self = self else {
                    return Fail(error: HueAPIError.unknown("Client deallocated"))
                        .eraseToAnyPublisher()
                }
                
                // Выполняем targeted search
                return self.performTargetedSearch(serialNumber: cleanSerial)
            }
            .flatMap { [weak self] _ -> AnyPublisher<[Light], Error> in
                guard let self = self else {
                    return Fail(error: HueAPIError.unknown("Client deallocated"))
                        .eraseToAnyPublisher()
                }
                
                // После поиска получаем обновленный список
                return self.getAllLightsV2HTTPS()
            }
            .map { allLights -> [Light] in
                // ВАЖНО: Фильтруем только НОВЫЕ лампы или те, что мигнули
                let newLights = allLights.filter { light in
                    // Новая лампа (не была в списке до поиска)
                    let isNew = !existingLightIds.contains(light.id)
                    
                    // Или лампа, которая мигнула (была сброшена)
                    // Проверяем по имени и состоянию
                    let isReset = light.metadata.name.contains("Hue") &&
                                 light.metadata.name.contains("lamp") &&
                                 !light.metadata.name.contains("configured")
                    
                    return isNew || isReset
                }
                
                print("🔍 Фильтрация результатов:")
                print("   Всего ламп: \(allLights.count)")
                print("   Новых/сброшенных: \(newLights.count)")
                
                // Если новых нет, но серийный номер валиден,
                // пытаемся найти по последним символам ID
                if newLights.isEmpty {
                    let matchingLight = allLights.first { light in
                        let lightIdSuffix = String(light.id.suffix(6))
                            .uppercased()
                            .replacingOccurrences(of: "-", with: "")
                        return lightIdSuffix == cleanSerial
                    }
                    
                    if let found = matchingLight {
                        print("✅ Найдена лампа по ID suffix: \(found.metadata.name)")
                        return [found]
                    }
                }
                
                return newLights
            }
            .eraseToAnyPublisher()
    }
    
    /// Автоматическое обнаружение через API v2
    internal func discoverLightsV2() -> AnyPublisher<[Light], Error> {
        print("🔍 Автоматическое обнаружение ламп через API v2")
        
        // Сохраняем текущий список для сравнения
        var currentLightIds = Set<String>()
        
        return getAllLightsV2HTTPS()
            .handleEvents(receiveOutput: { lights in
                currentLightIds = Set(lights.map { $0.id })
            })
            .delay(for: .seconds(3), scheduler: RunLoop.main)
            .flatMap { _ in
                // Повторный запрос для обнаружения новых
                self.getAllLightsV2HTTPS()
            }
            .map { updatedLights in
                // Находим новые лампы
                return updatedLights.filter { light in
                    !currentLightIds.contains(light.id) || light.isNewLight
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Минимальное использование v1 только для инициации поиска
    internal func initiateSearchV1(serial: String) -> AnyPublisher<Bool, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        // ЕДИНСТВЕННЫЙ v1 endpoint который нам нужен
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let body = ["deviceid": [serial.uppercased()]]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: HueAPIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        // Используем обычную сессию для локальной сети
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 v1 Search initiation response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        return true
                    } else if httpResponse.statusCode == 404 {
                        throw HueAPIError.bridgeNotFound
                    } else {
                        throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
                return true
            }
            .mapError { error in
                print("❌ Ошибка инициации поиска: \(error)")
                return HueAPIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    /// Выполняет targeted search для добавления новой лампы
    internal func performTargetedSearch(serialNumber: String) -> AnyPublisher<[Light], Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        print("🎯 Запускаем targeted search для: \(serialNumber)")
        
        // Инициируем поиск через API v1
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        // Формат для targeted search
        let body = ["deviceid": [serialNumber]]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: HueAPIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Targeted search response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        print("✅ Поиск инициирован успешно")
                        return true
                    } else {
                        throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
                return true
            }
            .delay(for: .seconds(40), scheduler: RunLoop.main) // Ждем 40 секунд согласно документации
            .flatMap { _ in
                // После ожидания проверяем новые лампы
                self.checkForNewLights()
            }
            .eraseToAnyPublisher()
    }
    
    /// Проверяет появление новых ламп после targeted search
    internal func checkForNewLights() -> AnyPublisher<[Light], Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        print("🔍 Проверяем новые лампы...")
        
        // Получаем результаты поиска через /lights/new
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights/new") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data in
                // Парсим ответ
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let lastscan = json["lastscan"] as? String {
                    
                    print("📅 Последнее сканирование: \(lastscan)")
                    
                    // Извлекаем ID новых ламп
                    var newLightIds: [String] = []
                    for (key, value) in json {
                        if key != "lastscan", let _ = value as? [String: Any] {
                            newLightIds.append(key)
                            print("   ✨ Найдена новая лампа: ID \(key)")
                        }
                    }
                    
                    return newLightIds
                } else {
                    return []
                }
            }
            .flatMap { lightIds -> AnyPublisher<[Light], Error> in
                if lightIds.isEmpty {
                    print("❌ Новые лампы не найдены")
                    return Just([])
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // Получаем данные о новых лампах через API v2
                return self.getAllLightsV2HTTPS()
                    .map { allLights in
                        // Фильтруем только новые лампы
                        return allLights.filter { light in
                            lightIds.contains { id in
                                light.id.contains(id) || light.metadata.name.contains("Hue light \(id)")
                            }
                        }
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Валидация серийного номера
    internal func isValidSerialNumber(_ serial: String) -> Bool {
        let cleaned = serial
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
        
        // ИСПРАВЛЕНО: Принимаем буквы A-Z и цифры 0-9
        let validCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        
        // Проверяем длину и символы
        let isValid = cleaned.count == 6 &&
                      cleaned.rangeOfCharacter(from: validCharacterSet.inverted) == nil
        
        print("🔍 Валидация серийного номера '\(serial)': \(isValid ? "✅" : "❌")")
        return isValid
    }
    
    // MARK: - Touchlink Implementation
    
    /// Современная реализация Touchlink через Entertainment API
    func performModernTouchlink(serialNumber: String) -> AnyPublisher<Bool, Error> {
        print("🔗 Запуск Touchlink через современный API")
        
        // Проверяем поддержку Entertainment API
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        // Используем Entertainment Configuration для Touchlink
        let endpoint = "/clip/v2/resource/entertainment_configuration"
        
        let touchlinkRequest = [
            "type": "entertainment_configuration",
            "metadata": [
                "name": "Touchlink Session"
            ],
            "action": [
                "action": "touchlink",
                "target": serialNumber.uppercased()
            ]
        ] as [String: Any]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: touchlinkRequest)
            
            return performRequestHTTPS<GenericResponse>(
                endpoint: endpoint,
                method: "POST",
                body: data
            )
            .map { (_: GenericResponse) in true }
            .catch { error -> AnyPublisher<Bool, Error> in
                print("⚠️ Entertainment Touchlink недоступен, используем fallback")
                return self.performClassicTouchlink(serialNumber: serialNumber)
            }
            .eraseToAnyPublisher()
        } catch {
            return Fail(error: HueAPIError.encodingError)
                .eraseToAnyPublisher()
        }
    }
    
    /// Классический Touchlink (fallback)
    internal func performClassicTouchlink(serialNumber: String) -> AnyPublisher<Bool, Error> {
        print("🔗 Fallback к классическому Touchlink")
        
        // Это единственный случай когда нужен v1 touchlink
        guard let applicationKey = applicationKey,
              let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/config") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["touchlink": true]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: HueAPIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { _ in true }
            .mapError { HueAPIError.networkError($0) }
            .eraseToAnyPublisher()
    }
    
    /// Получает детальную информацию об устройстве по ID для извлечения серийного номера
    /// - Parameter deviceId: ID устройства
    /// - Returns: Publisher с информацией об устройстве
    func getDeviceDetails(_ deviceId: String) -> AnyPublisher<DeviceDetails, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://\(bridgeIP)/clip/v2/resource/device/\(deviceId)") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        
        return sessionHTTPS.dataTaskPublisher(for: request)
            .tryMap { data, response in
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        throw HueAPIError.bridgeNotFound
                    } else if httpResponse.statusCode >= 400 {
                        throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
                return data
            }
            .decode(type: DeviceDetailsResponse.self, decoder: JSONDecoder())
            .map { $0.data.first }
            .compactMap { $0 }
            .mapError { error in
                HueAPIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+LightDiscovery.swift
 
 Описание:
 Расширение HueAPIClient для обнаружения и добавления новых ламп.
 Современная реализация с минимальным использованием API v1.
 
 Основные компоненты:
 - addLightModern - современный метод добавления ламп
 - addLightBySerialNumber - добавление по серийному номеру
 - discoverLightsV2 - автоматическое обнаружение v2
 - initiateSearchV1 - инициация поиска через v1
 - performTargetedSearch - целевой поиск лампы
 - checkForNewLights - проверка новых ламп
 - isValidSerialNumber - валидация серийного номера
 - performModernTouchlink - современный Touchlink
 - performClassicTouchlink - классический Touchlink
 - getDeviceDetails - получение деталей устройства
 
 Зависимости:
 - HueAPIClient базовый класс
 - getAllLightsV2HTTPS для получения списка ламп
 - performRequestHTTPS для сетевых запросов
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Lights.swift - методы управления лампами
 - HueAPIClient+DeviceMapping.swift - маппинг устройств
 */
