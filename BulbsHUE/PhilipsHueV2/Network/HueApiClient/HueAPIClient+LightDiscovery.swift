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
        // Для ОБЩЕГО поиска (без серийника) корректно инициируем v1 scan и сверяем результат
        if serialNumber == nil {
            return startGeneralSearchV1()
                .flatMap { _ in
                    // Робастный опрос /lights/new с ожиданием завершения сканирования
                    self.checkForNewLights()
                }
                .flatMap { [weak self] newLights -> AnyPublisher<[Light], Error> in
                    guard let self = self else {
                        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    // Если v1 сообщил новые ID, может потребоваться время, чтобы они появились в v2.
                    // Делаем ожидание с повторными попытками до 60с.
                    return self.awaitV2Enumeration(for: newLights)
                }
                .flatMap { [weak self] lights -> AnyPublisher<[Light], Error> in
                    guard let self = self else {
                        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    // Fallback: если ничего не нашли, пробуем Touchlink scan и повторяем цикл
                    if lights.isEmpty {
                        return self.triggerTouchlinkScan()
                            .delay(for: .seconds(8), scheduler: RunLoop.main)
                            .flatMap { _ in self.checkForNewLights() }
                            .flatMap { newV2Lights in self.awaitV2Enumeration(for: newV2Lights) }
                            .catch { _ in Just<[Light]>([]).setFailureType(to: Error.self).eraseToAnyPublisher() }
                            .eraseToAnyPublisher()
                    }
                    return Just(lights).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
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
            .map { lights in lights }
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
    
    /// Запускает общий поиск ламп на мосте через CLIP v1 (POST /lights)
    /// Согласно официальной документации Philips Hue API v1
    internal func startGeneralSearchV1() -> AnyPublisher<Bool, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL).eraseToAnyPublisher()
        }
        
        print("🔍 Инициируем общий поиск ламп через v1 API...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // ✅ НЕ устанавливаем Content-Type для пустого тела
        // request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0  // Увеличиваем таймаут до 60 секунд
        // ✅ НЕ устанавливаем httpBody - оставляем nil
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let http = response as? HTTPURLResponse else {
                    throw HueAPIError.networkError(NSError(domain: "No HTTP response", code: -1))
                }
                
                print("📡 Response status: \(http.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Response body: \(responseString)")
                }
                
                // Успешный запуск поиска возвращает массив с success
                if http.statusCode == 200 {
                    print("✅ Поиск запущен, ожидаем 40 секунд...")
                    return true
                } else {
                    throw HueAPIError.httpError(statusCode: http.statusCode)
                }
            }
            .delay(for: .seconds(40), scheduler: RunLoop.main)
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
    
    /// Проверяет появление новых ламп после общего поиска
        /// Правильная реализация согласно Philips Hue API v1 документации
        internal func checkForNewLights() -> AnyPublisher<[Light], Error> {
            guard let applicationKey = applicationKey else {
                return Fail(error: HueAPIError.notAuthenticated)
                    .eraseToAnyPublisher()
            }
            
            print("🔍 Проверяем новые лампы через /lights/new...")
            
            // Проверяем результаты поиска через v1 API
            return fetchNewLightsStatus()
                .flatMap { [weak self] newLightIds -> AnyPublisher<[Light], Error> in
                    guard let self = self else {
                        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    
                    print("🆕 API v1 сообщает о новых ID: \(newLightIds)")
                    
                    // Если v1 говорит что новых нет, но мы знаем что лампы подключены,
                    // возвращаем ВСЕ лампы чтобы пользователь мог их настроить
                    if newLightIds.isEmpty {
                        print("⚠️ v1 API не видит новых ламп, проверяем все существующие...")
                        
                        // Получаем все лампы и показываем их как доступные для настройки
                        return self.getAllLightsV2HTTPS()
                            .map { allLights -> [Light] in
                                print("📊 Показываем все лампы для настройки: \(allLights.count)")
                                
                                // Возвращаем все лампы, которые еще не настроены в приложении
                                let unconfiguredLights = allLights.filter { light in
                                    // Проверяем, есть ли у лампы пользовательская категория
                                    let hasUserConfig = light.metadata.userSubtypeName != nil &&
                                                      !light.metadata.userSubtypeName!.isEmpty
                                    
                                    if !hasUserConfig {
                                        print("📍 Лампа '\(light.metadata.name)' доступна для настройки")
                                    }
                                    
                                    return !hasUserConfig
                                }
                                
                                // Если все лампы уже настроены, показываем все для возможности перенастройки
                                if unconfiguredLights.isEmpty && !allLights.isEmpty {
                                    print("ℹ️ Все лампы настроены, показываем все для возможности изменения")
                                    return allLights
                                }
                                
                                return unconfiguredLights
                            }
                            .eraseToAnyPublisher()
                    }
                    
                    // Если v1 нашел новые лампы, возвращаем их
                    return self.getAllLightsV2HTTPS()
                        .map { allLights -> [Light] in
                            // Находим лампы по v1 ID
                            let newLights = allLights.filter { light in
                                // Проверяем соответствие v1 ID
                                for v1Id in newLightIds {
                                    if light.id.contains(v1Id) || light.metadata.name.contains("lamp \(v1Id)") {
                                        print("✨ Найдена новая лампа: \(light.metadata.name) (ID: \(light.id))")
                                        return true
                                    }
                                }
                                return false
                            }
                            
                            // Если не нашли по ID, возвращаем все ненастроенные
                            if newLights.isEmpty {
                                return allLights.filter { $0.metadata.userSubtypeName == nil }
                            }
                            
                            return newLights
                        }
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
    
    /// Получает статус поиска новых ламп из API v1
    func fetchNewLightsStatus() -> AnyPublisher<[String], Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights/new") else {
            return Fail(error: HueAPIError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data in
                // Диагностический вывод
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📡 Raw response from /lights/new: \(jsonString)")
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ Не удалось распарсить JSON ответ")
                    return []
                }
                
                let lastscan = json["lastscan"] as? String ?? "none"
                print("📅 Статус последнего сканирования: \(lastscan)")
                
                var newLightIds: [String] = []
                for (key, value) in json where key != "lastscan" {
                    if let lightInfo = value as? [String: Any] {
                        print("💡 Найдена новая лампа v1 ID: \(key), info: \(lightInfo)")
                        newLightIds.append(key)
                    }
                }
                
                return newLightIds
            }
            .mapError { HueAPIError.networkError($0) }
            .eraseToAnyPublisher()
    }
    
    private func fetchNewOnce() -> AnyPublisher<(ids: [String], lastscan: String), Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated).eraseToAnyPublisher()
        }
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights/new") else {
            return Fail(error: HueAPIError.invalidURL).eraseToAnyPublisher()
        }
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let lastscan = json["lastscan"] as? String else {
                    return ([], "none")
                }
                var newLightIds: [String] = []
                for (key, value) in json where key != "lastscan" {
                    if let _ = value as? [String: Any] { newLightIds.append(key) }
                }
                return (newLightIds, lastscan)
            }
            .mapError { HueAPIError.networkError($0) }
            .eraseToAnyPublisher()
    }
    
    private func pollNewIds(elapsed: TimeInterval, timeout: TimeInterval, interval: TimeInterval) -> AnyPublisher<[String], Error> {
        return fetchNewOnce()
            .flatMap { result -> AnyPublisher<[String], Error> in
                let (ids, lastscan) = result
                print("📅 lastscan=\(lastscan), найдено новых: \(ids.count), elapsed=\(Int(elapsed))s")
                if (lastscan == "active" || lastscan == "none") && elapsed < timeout {
                    return Just(())
                        .delay(for: .seconds(interval), scheduler: RunLoop.main)
                        .flatMap { _ in self.pollNewIds(elapsed: elapsed + interval, timeout: timeout, interval: interval) }
                        .eraseToAnyPublisher()
                } else {
                    return Just(ids).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Триггерит Touchlink scan (v1 PUT /config {"touchlink": true}) для принудительного поиска устройств
    private func triggerTouchlinkScan() -> AnyPublisher<Bool, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated).eraseToAnyPublisher()
        }
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/config") else {
            return Fail(error: HueAPIError.invalidURL).eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["touchlink": true])
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { _ in true }
            .mapError { HueAPIError.networkError($0) }
            .eraseToAnyPublisher()
    }

    /// Дожидается появления новых ламп в API v2 (повторные попытки до 60с)
    private func awaitV2Enumeration(for v2CandidateLights: [Light], timeout: TimeInterval = 60, interval: TimeInterval = 2) -> AnyPublisher<[Light], Error> {
        if v2CandidateLights.isEmpty {
            return getAllLightsV2HTTPS()
                .eraseToAnyPublisher()
        }
        func attempt(elapsed: TimeInterval) -> AnyPublisher<[Light], Error> {
            return getAllLightsV2HTTPS()
                .map { all in
                    let ids = Set(v2CandidateLights.map { $0.id })
                    let present = all.filter { ids.contains($0.id) }
                    return present
                }
                .flatMap { present -> AnyPublisher<[Light], Error> in
                    if !present.isEmpty || elapsed >= timeout {
                        return Just(present).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    return Just(())
                        .delay(for: .seconds(interval), scheduler: RunLoop.main)
                        .flatMap { _ in attempt(elapsed: elapsed + interval) }
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        return attempt(elapsed: 0)
    }

    /// Ждёт появления соответствующих v2-ламп для заданных v1 ID (до 60с)
    private func awaitV2EnumerationForV1Ids(_ v1Ids: [String], timeout: TimeInterval = 60, interval: TimeInterval = 2) -> AnyPublisher<[Light], Error> {
        if v1Ids.isEmpty {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        func attempt(elapsed: TimeInterval) -> AnyPublisher<[Light], Error> {
            return getDeviceMappings()
                .flatMap { mappings -> AnyPublisher<[Light], Error> in
                    self.getAllLightsV2HTTPS()
                        .map { allV2 in
                            let v1IdSet = Set(v1Ids)
                            let matchedV2Ids = mappings.compactMap { m -> String? in
                                if let v1 = m.v1LightId, v1IdSet.contains(v1) { return m.lightId }
                                return nil
                            }
                            if matchedV2Ids.isEmpty {
                                return allV2.filter { v2 in v1IdSet.contains(where: { v2.id.contains($0) }) }
                            }
                            return allV2.filter { matchedV2Ids.contains($0.id) }
                        }
                        .eraseToAnyPublisher()
                }
                .flatMap { matched -> AnyPublisher<[Light], Error> in
                    if !matched.isEmpty || elapsed >= timeout {
                        return Just(matched).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    return Just(())
                        .delay(for: .seconds(interval), scheduler: RunLoop.main)
                        .flatMap { _ in attempt(elapsed: elapsed + interval) }
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        return attempt(elapsed: 0)
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
