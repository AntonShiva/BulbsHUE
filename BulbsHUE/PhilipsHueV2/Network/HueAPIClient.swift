//
//  HueAPIClient.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine
import Network

/// Основной клиент для взаимодействия с Philips Hue API v2
/// Использует HTTPS подключение с проверкой сертификатов
/// Поддерживает все основные endpoint'ы API v2
///
/// Рекомендации по производительности:
/// - Максимум 10 команд в секунду для /lights с задержкой 100мс между вызовами
/// - Максимум 1 команда в секунду для /groups
/// - Для длительных обновлений используйте Entertainment Streaming API
class HueAPIClient: NSObject {
    
    // MARK: - Properties
    
    /// IP адрес Hue Bridge в локальной сети
    private let bridgeIP: String
    
    /// Application Key для авторизации в API
    /// В API v2 заменяет старое понятие "username"
    /// Должен храниться в безопасном месте
    private var applicationKey: String?
    
    /// Сервис для персистентного хранения данных
    private weak var dataPersistenceService: DataPersistenceService?
    
    /// Weak reference на LightsViewModel для обновления статуса связи
    private weak var lightsViewModel: LightsViewModel?
    
    /// URLSession с настроенной проверкой сертификата
    /// Исправлено для iOS 17+ совместимости
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // ИСПРАВЛЕНИЕ: Убираем multipathServiceType для iOS 17+ совместимости
        // Это исправляет ошибки nw_protocol_socket_set_no_wake_from_sleep
        if #available(iOS 16.0, *) {
            // Для iOS 16+ используем более консервативные настройки
            configuration.allowsConstrainedNetworkAccess = false
            configuration.allowsExpensiveNetworkAccess = true
        } else {
            // Старое поведение для совместимости
            configuration.multipathServiceType = .handover
            configuration.allowsConstrainedNetworkAccess = true
        }
        
        // Улучшенные настройки для локальной сети
        configuration.waitsForConnectivity = false
        configuration.networkServiceType = .default
        
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    /// Базовый URL для API endpoint'ов
    /// Используем HTTP для локальных подключений, HTTPS только для удаленных
    private var baseURL: URL? {
        // Для локальной сети используем HTTP (Hue Bridge поддерживает HTTP на порту 80)
        URL(string: "http://\(bridgeIP)")
    }
    
    /// Combine publisher для обработки ошибок
    private let errorSubject = PassthroughSubject<HueAPIError, Never>()
    var errorPublisher: AnyPublisher<HueAPIError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    /// Publisher для Server-Sent Events
    private let eventSubject = PassthroughSubject<HueEvent, Never>()
    var eventPublisher: AnyPublisher<HueEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Активная задача для SSE потока
    private var eventStreamTask: URLSessionDataTask?
    
    /// Буфер для SSE данных
    private var eventStreamBuffer = Data()
    
    /// Очередь для ограничения скорости запросов
    private let throttleQueue = DispatchQueue(label: "com.hue.throttle", qos: .userInitiated)
    
    /// Время последнего запроса к lights
    private var lastLightRequestTime = Date.distantPast
    
    /// Время последнего запроса к groups
    private var lastGroupRequestTime = Date.distantPast
    
    /// Минимальный интервал между запросами к lights (100мс)
    private let lightRequestInterval: TimeInterval = 0.1
    
    /// Минимальный интервал между запросами к groups (1с)
    private let groupRequestInterval: TimeInterval = 1.0
    
    /// Набор подписок
    private var cancellables = Set<AnyCancellable>()
    
    /// Специальная HTTPS сессия с правильной проверкой сертификата Hue Bridge
    private lazy var sessionHTTPS: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // ИСПРАВЛЕНИЕ: Убираем multipathServiceType для iOS 17+ совместимости
        // Это исправляет ошибки nw_protocol_socket_set_no_wake_from_sleep
        if #available(iOS 16.0, *) {
            // Для iOS 16+ используем более консервативные настройки
            configuration.allowsConstrainedNetworkAccess = false
            configuration.allowsExpensiveNetworkAccess = true
        } else {
            // Старое поведение для совместимости
            configuration.multipathServiceType = .handover
            configuration.allowsConstrainedNetworkAccess = true
        }
        
        configuration.waitsForConnectivity = false
        configuration.networkServiceType = .default
        
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    // MARK: - Initialization
    
    /// Инициализирует клиент с IP адресом моста
    /// - Parameters:
    ///   - bridgeIP: IP адрес Hue Bridge
    ///   - dataPersistenceService: Сервис для работы с данными
    init(bridgeIP: String, dataPersistenceService: DataPersistenceService? = nil) {
        self.bridgeIP = bridgeIP
        self.dataPersistenceService = dataPersistenceService
        super.init()
    }
    
    /// Устанавливает application key для авторизации
    /// - Parameter key: Application key полученный при регистрации
    func setApplicationKey(_ key: String) {
        self.applicationKey = key
    }
    
    /// Устанавливает LightsViewModel для обновления статуса связи
    /// - Parameter viewModel: LightsViewModel который будет получать обновления статуса
    func setLightsViewModel(_ viewModel: LightsViewModel) {
        self.lightsViewModel = viewModel
    }
    
    // MARK: - Authentication
    
    // Добавьте этот метод после performTargetedSearch

    /// Проверяет, мигнула ли лампа (подтверждение сброса)
    private func checkLightBlink(lightId: String) -> AnyPublisher<Bool, Error> {
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
    
    /// Создает нового пользователя (application key) на мосту
    /// Требует нажатия кнопки Link на физическом устройстве
    /// - Parameters:
    ///   - appName: Имя приложения для идентификации
    ///   - deviceName: Имя устройства для идентификации
    /// - Returns: Combine Publisher с результатом авторизации
    func createUser(appName: String, deviceName: String) -> AnyPublisher<AuthenticationResponse, Error> {
        guard let url = baseURL?.appendingPathComponent("/api") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "devicetype": "\(appName)#\(deviceName)",
            "generateclientkey": true
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Проверяем статус ответа
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status: \(httpResponse.statusCode)")
                    
                    // В случае ошибки Link Button мост возвращает статус 200, но с ошибкой в теле
                    if httpResponse.statusCode == 200 {
                        return data
                    } else if httpResponse.statusCode == 403 {
                        throw HueAPIError.linkButtonNotPressed
                    }
                }
                throw HueAPIError.invalidResponse
            }
            .decode(type: [AuthenticationResponse].self, decoder: JSONDecoder())
            .compactMap { responses in
                // Philips Hue возвращает массив, берем первый элемент
                responses.first
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Bridge Discovery (mDNS & Cloud)
    
    /// Поиск Hue Bridge через облачный сервис Philips
    /// - Returns: Combine Publisher со списком найденных мостов
    func discoverBridgesViaCloud() -> AnyPublisher<[Bridge], Error> {
        guard let url = URL(string: "https://discovery.meethue.com") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        // Используем shared session для внешних запросов
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Bridge].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    /// Поиск Hue Bridge через новый SSDP discovery
    /// - Returns: Combine Publisher со списком найденных мостов
    func discoverBridges() -> AnyPublisher<[Bridge], Error> {
        return Future<[Bridge], Error> { promise in
            if #available(iOS 12.0, *) {
                let discovery = HueBridgeDiscovery()
                discovery.discoverBridges { bridges in
                    if bridges.isEmpty {
                        promise(.failure(HueAPIError.bridgeNotFound))
                    } else {
                        promise(.success(bridges))
                    }
                }
            } else {
                // Fallback для старых версий iOS
                promise(.failure(HueAPIError.bridgeNotFound))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Configuration & Capabilities
    
    /// Получает конфигурацию моста
    /// - Returns: Combine Publisher с конфигурацией
    func getBridgeConfig() -> AnyPublisher<BridgeConfig, Error> {
        let endpoint = "/api/0/config"
        return performRequest(endpoint: endpoint, method: "GET", authenticated: false)
    }
    
    /// Получает возможности моста (лимиты ресурсов)
    /// - Returns: Combine Publisher с возможностями
    func getBridgeCapabilities() -> AnyPublisher<BridgeCapabilities, Error> {
        guard applicationKey != nil else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        let endpoint = "/api/\(applicationKey!)/capabilities"
        return performRequest(endpoint: endpoint, method: "GET", authenticated: false)
    }
    
    // MARK: - Lights Endpoints
    
    /// Получает список всех ламп в системе
    /// ИСПРАВЛЕННЫЙ getAllLights - использует только API v2 через HTTPS
    /// - Returns: Combine Publisher со списком ламп
    func getAllLights() -> AnyPublisher<[Light], Error> {
        print("🚀 Используем API v2 через HTTPS...")
        return getAllLightsV2HTTPS()
    }
    

    /// Проверяет наличие валидного подключения к мосту
        func hasValidConnection() -> Bool {
            return applicationKey != nil && !bridgeIP.isEmpty
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
    private func performOffLightBlink(id: String) -> AnyPublisher<Bool, Error> {
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
    private func performBrightnessBlink(id: String, originalBrightness: Double) -> AnyPublisher<Bool, Error> {
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
    
    // MARK: - Scenes Endpoints
    
    /// Получает список всех сцен
    /// - Returns: Combine Publisher со списком сцен
    func getAllScenes() -> AnyPublisher<[HueScene], Error> {
        let endpoint = "/clip/v2/resource/scene"
        return performRequestHTTPS<ScenesResponse>(endpoint: endpoint, method: "GET")
            .map { (response: ScenesResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Активирует сцену
    /// - Parameter sceneId: Уникальный идентификатор сцены
    /// - Returns: Combine Publisher с результатом активации
    func activateScene(sceneId: String) -> AnyPublisher<Bool, Error> {
        let endpoint = "/clip/v2/resource/scene/\(sceneId)"
        
        let body = SceneActivation(recall: RecallAction(action: "active"))
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(body)
            
            return performRequestHTTPS<GenericResponse>(endpoint: endpoint, method: "PUT", body: data)
                .map { (_: GenericResponse) in true }
                .catch { error -> AnyPublisher<Bool, Error> in
                    print("Error activating scene: \(error)")
                    return Just(false)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Создает новую сцену
    /// - Parameters:
    ///   - name: Название сцены
    ///   - lights: Список идентификаторов ламп для сцены
    ///   - room: Идентификатор комнаты (опционально)
    /// - Returns: Combine Publisher с созданной сценой
    func createScene(name: String, lights: [String], room: String? = nil) -> AnyPublisher<HueScene, Error> {
        let endpoint = "/clip/v2/resource/scene"
        
        var scene = HueScene()
        scene.metadata.name = name
        scene.actions = lights.map { lightId in
            SceneAction(
                target: ResourceIdentifier(rid: lightId, rtype: "light"),
                action: nil
            )
        }
        
        if let room = room {
            scene.group = ResourceIdentifier(rid: room, rtype: "room")
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scene)
            
            return performRequestHTTPS<SceneResponse>(endpoint: endpoint, method: "POST", body: data)
                .map { (response: SceneResponse) in
                    response.data.first ?? HueScene()
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Groups (Rooms/Zones) Endpoints
    
    /// Получает список всех групп (комнат и зон)
    /// - Returns: Combine Publisher со списком групп
    func getAllGroups() -> AnyPublisher<[HueGroup], Error> {
        let endpoint = "/clip/v2/resource/grouped_light"
        return performRequestHTTPS<GroupsResponse>(endpoint: endpoint, method: "GET")
            .map { (response: GroupsResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Обновляет состояние группы ламп с учетом ограничений производительности
    /// - Parameters:
    ///   - id: Идентификатор группы
    ///   - state: Новое состояние для всех ламп в группе
    /// - Returns: Combine Publisher с результатом операции
    func updateGroup(id: String, state: GroupState) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            self?.throttleQueue.async {
                guard let self = self else {
                    promise(.failure(HueAPIError.invalidResponse))
                    return
                }
                
                // Проверяем ограничение скорости для groups (1 команда в секунду)
                let now = Date()
                let timeSinceLastRequest = now.timeIntervalSince(self.lastGroupRequestTime)
                
                if timeSinceLastRequest < self.groupRequestInterval {
                    // Ждем оставшееся время
                    let delay = self.groupRequestInterval - timeSinceLastRequest
                    Thread.sleep(forTimeInterval: delay)
                }
                
                self.lastGroupRequestTime = Date()
                
                let endpoint = "/clip/v2/resource/grouped_light/\(id)"
                
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(state)
                    
                    self.performRequest(endpoint: endpoint, method: "PUT", body: data)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    print("Error updating group: \(error)")
                                    promise(.success(false))
                                } else {
                                    promise(.success(true))
                                }
                            },
                            receiveValue: { (_: GenericResponse) in
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
    
    // MARK: - Sensors Endpoints
    
    /// Получает список всех сенсоров
    /// - Returns: Combine Publisher со списком сенсоров
    func getAllSensors() -> AnyPublisher<[HueSensor], Error> {
        let endpoint = "/clip/v2/resource/device"
        return performRequestHTTPS<SensorsResponse>(endpoint: endpoint, method: "GET")
            .map { (response: SensorsResponse) in
                response.data.filter { device in
                    // Фильтруем только устройства с сенсорами
                    device.services?.contains { service in
                        ["motion", "light_level", "temperature", "button"].contains(service.rtype)
                    } ?? false
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает информацию о конкретном сенсоре
    /// - Parameter id: Идентификатор сенсора
    /// - Returns: Combine Publisher с информацией о сенсоре
    func getSensor(id: String) -> AnyPublisher<HueSensor, Error> {
        let endpoint = "/clip/v2/resource/device/\(id)"
        return performRequestHTTPS<SensorResponse>(endpoint: endpoint, method: "GET")
            .map { (response: SensorResponse) in
                response.data.first ?? HueSensor()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Rules Endpoints
    
    /// Получает список всех правил
    /// - Returns: Combine Publisher со списком правил
    func getAllRules() -> AnyPublisher<[HueRule], Error> {
        let endpoint = "/clip/v2/resource/behavior_script"
        return performRequestHTTPS<RulesResponse>(endpoint: endpoint, method: "GET")
            .map { (response: RulesResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Создает новое правило
    /// - Parameters:
    ///   - name: Название правила
    ///   - conditions: Условия срабатывания
    ///   - actions: Действия при срабатывании
    /// - Returns: Combine Publisher с созданным правилом
    func createRule(name: String, conditions: [RuleCondition], actions: [RuleAction]) -> AnyPublisher<HueRule, Error> {
        let endpoint = "/clip/v2/resource/behavior_script"
        
        var rule = HueRule()
        rule.metadata.name = name
        rule.configuration = RuleConfiguration(
            conditions: conditions,
            actions: actions
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(rule)
            
            return performRequestHTTPS<RuleResponse>(endpoint: endpoint, method: "POST", body: data)
                .map { (response: RuleResponse) in
                    response.data.first ?? HueRule()
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Включает или выключает правило
    /// - Parameters:
    ///   - id: Идентификатор правила
    ///   - enabled: Флаг включения
    /// - Returns: Combine Publisher с результатом
    func setRuleEnabled(id: String, enabled: Bool) -> AnyPublisher<Bool, Error> {
        let endpoint = "/clip/v2/resource/behavior_script/\(id)"
        
        let body = ["enabled": enabled]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            
            return performRequestHTTPS<GenericResponse>(endpoint: endpoint, method: "PUT", body: data)
                .map { (_: GenericResponse) in true }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Event Stream (Server-Sent Events)
    
    /// Подключается к потоку событий для получения обновлений в реальном времени
    /// Использует Server-Sent Events (SSE) для минимизации нагрузки
    /// - Returns: Combine Publisher с событиями
    func connectToEventStream() -> AnyPublisher<HueEvent, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = baseURL?.appendingPathComponent("/eventstream/clip/v2") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = TimeInterval.infinity
        
        return Future<HueEvent, Error> { [weak self] promise in
            self?.eventStreamTask = self?.session.dataTask(with: request)
            self?.eventStreamTask?.resume()
        }
        .eraseToAnyPublisher()
    }
    
    /// Отключается от потока событий
    func disconnectEventStream() {
        eventStreamTask?.cancel()
        eventStreamTask = nil
        eventStreamBuffer = Data()
    }
    
    // MARK: - Private Methods
    
    /// Парсит событие в формате SSE
    private func parseSSEEvent(_ data: Data) {
        eventStreamBuffer.append(data)
        
        // Конвертируем в строку для поиска событий
        guard let string = String(data: eventStreamBuffer, encoding: .utf8) else { return }
        
        // SSE события разделяются двойным переводом строки
        let events = string.components(separatedBy: "\n\n")
        
        for (index, eventString) in events.enumerated() {
            // Последний элемент может быть неполным
            if index == events.count - 1 && !eventString.isEmpty {
                // Сохраняем неполное событие в буфере
                eventStreamBuffer = eventString.data(using: .utf8) ?? Data()
                break
            }
            
            // Парсим полное событие
            if !eventString.isEmpty {
                parseSSEEventString(eventString)
            }
        }
        
        // Если обработали все события, очищаем буфер
        if events.last?.isEmpty == true {
            eventStreamBuffer = Data()
        }
    }
    
    /// Парсит строку события SSE
    private func parseSSEEventString(_ eventString: String) {
        let lines = eventString.components(separatedBy: "\n")
        var eventType: String?
        var eventData: String?
        var eventId: String?
        
        for line in lines {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7))
            } else if line.hasPrefix("data: ") {
                eventData = String(line.dropFirst(6))
            } else if line.hasPrefix("id: ") {
                eventId = String(line.dropFirst(4))
            }
        }
        
        // Парсим JSON данные события
        guard let eventData = eventData,
              let data = eventData.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let events = try decoder.decode([HueEvent].self, from: data)
            
            for event in events {
                eventSubject.send(event)
            }
        } catch {
            print("Error parsing SSE event: \(error)")
        }
    }
    
    /// Выполняет HTTP запрос к API
    /// - Parameters:
    ///   - endpoint: Путь к endpoint'у
    ///   - method: HTTP метод
    ///   - body: Тело запроса (опционально)
    ///   - authenticated: Требуется ли аутентификация (по умолчанию true)
    /// - Returns: Combine Publisher с декодированным ответом
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: Data? = nil,
        authenticated: Bool = true
    ) -> AnyPublisher<T, Error> {
        if authenticated {
            guard let applicationKey = applicationKey else {
                print("❌ Нет application key для аутентифицированного запроса")
                return Fail(error: HueAPIError.notAuthenticated)
                    .eraseToAnyPublisher()
            }
        }
        
        guard let url = baseURL?.appendingPathComponent(endpoint) else {
            print("❌ Невозможно создать URL: baseURL=\(baseURL?.absoluteString ?? "nil"), endpoint=\(endpoint)")
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        print("📤 HTTP \(method) запрос: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if authenticated, let applicationKey = applicationKey {
            request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
            print("🔑 Добавлен заголовок hue-application-key: \(String(applicationKey.prefix(8)))...")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
            print("📦 Тело запроса: \(String(data: body, encoding: .utf8) ?? "не удалось декодировать")")
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Ответ не является HTTP ответом")
                    throw HueAPIError.invalidResponse
                }
                
                print("📥 HTTP \(httpResponse.statusCode) ответ от \(url.absoluteString)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Тело ответа: \(responseString)")
                } else {
                    print("📄 Тело ответа: данные не декодируются как строка (\(data.count) байт)")
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    print("❌ HTTP ошибка \(httpResponse.statusCode)")
                    
                    // Проверяем специфичные ошибки
                    if httpResponse.statusCode == 403 {
                        print("🚫 403 Forbidden - возможно нужно нажать кнопку link на мосту")
                        throw HueAPIError.linkButtonNotPressed
                    } else if httpResponse.statusCode == 503 {
                        print("⚠️ 503 Service Unavailable - буфер мостa переполнен")
                        throw HueAPIError.bufferFull
                    } else if httpResponse.statusCode == 429 {
                        print("⏱ 429 Too Many Requests - превышен лимит запросов")
                        throw HueAPIError.rateLimitExceeded
                    } else if httpResponse.statusCode == 404 {
                        print("🔍 404 Not Found - endpoint не существует")
                        print("   Проверьте поддержку API v2 на мосту")
                    } else if httpResponse.statusCode == 401 {
                        print("🔐 401 Unauthorized - проблема с аутентификацией")
                        print("   Проверьте application key")
                    }
                    
                    throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                }
                
                print("✅ HTTP запрос успешен")
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .catch { error in
                if error is DecodingError {
                    print("❌ Ошибка декодирования JSON: \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("   Данные повреждены: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("   Ключ не найден: \(key.stringValue) в \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("   Неправильный тип: ожидался \(type), контекст: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("   Значение не найдено: \(type), контекст: \(context.debugDescription)")
                        @unknown default:
                            print("   Неизвестная ошибка декодирования")
                        }
                    }
                }
                return Fail<T, Error>(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
//
//  HueAPIClient+LightDiscovery.swift
//  BulbsHUE
//
//  Современная реализация добавления ламп с минимальным использованием API v1
//


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
    
    /// Автоматическое обнаружение через API v2
    private func discoverLightsV2() -> AnyPublisher<[Light], Error> {
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
    private func initiateSearchV1(serial: String) -> AnyPublisher<Bool, Error> {
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
    
    /// Валидация серийного номера
    /// Валидация серийного номера
    private func isValidSerialNumber(_ serial: String) -> Bool {
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
    }}

// MARK: - Touchlink Implementation

extension HueAPIClient {
    
    /// Современная реализация Touchlink через Entertainment API
    
    
    /// Классический Touchlink (fallback)
    private func performClassicTouchlink(serialNumber: String) -> AnyPublisher<Bool, Error> {
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
}

// Расширение для HueAPIClient для поддержки поиска ламп
extension HueAPIClient {
    

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
            .map { (_: GenericResponse) in true }  // ← ИСПРАВЛЕНО: добавлен тип параметра
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
    
    /// Получает список всех ламп через API v1 (может содержать серийные номера)
    /// - Returns: Publisher с информацией о лампах v1
    func getLightsV1() -> AnyPublisher<[String: LightV1Data], Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("📤 HTTP GET запрос v1: \(url)")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                if let httpResponse = response as? HTTPURLResponse {
                    print("📥 HTTP \(httpResponse.statusCode) ответ от \(url)")
                    
                    if httpResponse.statusCode == 404 {
                        throw HueAPIError.bridgeNotFound
                    } else if httpResponse.statusCode >= 400 {
                        throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 HTTPS тело ответа v1: \(responseString.prefix(500))...")
                }
                
                return data
            }
            .decode(type: [String: LightV1Data].self, decoder: JSONDecoder())
            .mapError { error in
                print("❌ Ошибка получения ламп v1: \(error)")
                return HueAPIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
}


// MARK: - URLSessionDelegate

extension HueAPIClient: URLSessionDelegate, URLSessionDataDelegate {
    /// Проверяет сертификат Hue Bridge
    /// Поддерживает как Signify CA, так и Google Trust Services (с 2025)
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Проверяем сертификат Philips Hue Bridge
        // 1. Пробуем загрузить корневой сертификат Signify
        if let certPath = Bundle.main.path(forResource: "HueBridgeCACert", ofType: "pem"),
           let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)),
           let certString = String(data: certData, encoding: .utf8) {
            
            print("Найден сертификат HueBridgeCACert.pem")
            
            // Удаляем заголовки PEM и переводы строк
            let lines = certString.components(separatedBy: .newlines)
            let certBase64 = lines.filter {
                !$0.contains("BEGIN CERTIFICATE") && 
                !$0.contains("END CERTIFICATE") && 
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.joined()
            
            if let decodedData = Data(base64Encoded: certBase64),
               let certificate = SecCertificateCreateWithData(nil, decodedData as CFData) {
                
                print("Сертификат успешно декодирован")
                
                // Создаем политику для проверки SSL с hostname verification
                let policy = SecPolicyCreateSSL(true, bridgeIP as CFString)
                
                // Создаем trust объект с загруженным сертификатом
                var trust: SecTrust?
                let status = SecTrustCreateWithCertificates([certificate] as CFArray, policy, &trust)
                
                if status == errSecSuccess, let trust = trust {
                    // Устанавливаем якорные сертификаты
                    SecTrustSetAnchorCertificates(trust, [certificate] as CFArray)
                    SecTrustSetAnchorCertificatesOnly(trust, true)
                    
                    var result: SecTrustResultType = .invalid
                    let evalStatus = SecTrustEvaluate(trust, &result)
                    
                    print("Результат проверки сертификата: \(result.rawValue)")
                    
                    if evalStatus == errSecSuccess && 
                       (result == .unspecified || result == .proceed) {
                        let credential = URLCredential(trust: serverTrust)
                        completionHandler(.useCredential, credential)
                        return
                    }
                }
            } else {
                print("Ошибка декодирования сертификата")
            }
        } else {
            print("Сертификат HueBridgeCACert.pem не найден в Bundle")
        }
        
        // Fallback: для локальных IP разрешаем подключение с любым сертификатом
        // (Hue Bridge может использовать самоподписанный сертификат)
        if bridgeIP.hasPrefix("192.168.") || bridgeIP.hasPrefix("10.") || bridgeIP.hasPrefix("172.") {
            print("Разрешаем подключение к локальному IP: \(bridgeIP)")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("Отклоняем подключение к удаленному IP: \(bridgeIP)")
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    /// Обрабатывает получение данных для SSE
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if dataTask == eventStreamTask {
            parseSSEEvent(data)
        }
    }
    
    // MARK: - Communication Status Management
    
    /// Проверяет ошибки связи в ответе API и обновляет статус лампы
    private func checkCommunicationErrors(lightId: String, response: GenericResponse) {
        guard let errors = response.errors, !errors.isEmpty else {
            // Нет ошибок - лампа в сети
            updateLightCommunicationStatus(lightId: lightId, status: .online)
            return
        }
        
        for error in errors {
            if let description = error.description {
                print("[HueAPIClient] Ошибка для лампы \(lightId): \(description)")
                
                if description.contains("communication issues") || 
                   description.contains("command may not have effect") ||
                   description.contains("device unreachable") ||
                   description.contains("unreachable") {
                    updateLightCommunicationStatus(lightId: lightId, status: .issues)
                    return
                }
            }
        }
        
        // Если есть ошибки, но не связанные со связью
        updateLightCommunicationStatus(lightId: lightId, status: .online)
    }
    
    /// Обновляет статус связи лампы в LightsViewModel (в памяти)
    private func updateLightCommunicationStatus(lightId: String, status: CommunicationStatus) {
        DispatchQueue.main.async { [weak self] in
            print("[HueAPIClient] Обновляем статус связи лампы \(lightId): \(status)")
            
            // Обновляем статус в LightsViewModel для мгновенного отклика UI
            if let lightsViewModel = self?.lightsViewModel {
                lightsViewModel.updateLightCommunicationStatus(lightId: lightId, status: status)
                print("[HueAPIClient] ✅ Статус связи обновлен в LightsViewModel")
            } else {
                print("[HueAPIClient] ⚠️ LightsViewModel недоступен для обновления статуса")
            }
        }
    }
}

extension HueAPIClient {
    
    /// Создает нового пользователя с правильной обработкой локальной сети
    func createUserWithLocalNetworkCheck(appName: String, deviceName: String) -> AnyPublisher<AuthenticationResponse, Error> {
        // Используем HTTPS для API v2 (современный безопасный подход)
        guard let url = baseURLHTTPS?.appendingPathComponent("/api") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // Увеличенный таймаут для HTTPS
        
        let body = [
            "devicetype": "\(appName)#\(deviceName)",
            "generateclientkey": true
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        // Используем HTTPS сессию с правильной проверкой сертификата
        return sessionHTTPS.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Логируем ответ для отладки
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 HueAPIClient: HTTPS Status: \(httpResponse.statusCode)")
                    print("🌐 HueAPIClient: URL: \(httpResponse.url?.absoluteString ?? "unknown")")
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📦 HueAPIClient: Response: \(responseString)")
                    }
                    
                    // Проверяем статус код
                    if httpResponse.statusCode != 200 {
                        print("❌ HueAPIClient: Неожиданный статус код: \(httpResponse.statusCode)")
                        if httpResponse.statusCode == 403 {
                            throw HueAPIError.localNetworkPermissionDenied
                        }
                    }
                }
                
                return data
            }
            .decode(type: [AuthenticationResponse].self, decoder: JSONDecoder())
            .tryMap { responses in
                print("🔍 HueAPIClient: Получено \(responses.count) ответов")
                
                // Проверяем ответ
                if let response = responses.first {
                    print("🔍 HueAPIClient: Первый ответ: \(response)")
                    
                    if let error = response.error {
                        print("❌ HueAPIClient: Hue API Error - Type: \(error.type ?? -1), Description: \(error.description ?? "Unknown")")
                        
                        // Код 101 означает что кнопка Link не нажата
                        if error.type == 101 {
                            print("⏳ HueAPIClient: Link button not pressed (code 101)")
                            throw HueAPIError.linkButtonNotPressed
                        } else {
                            print("⚠️ HueAPIClient: Other Hue API error: \(error.type ?? 0)")
                            throw HueAPIError.httpError(statusCode: error.type ?? 0)
                        }
                    } else if let success = response.success {
                        print("✅ HueAPIClient: Успешная авторизация! Username: \(success.username ?? "unknown")")
                        return response
                    } else {
                        print("❌ HueAPIClient: Ответ не содержит ни success, ни error")
                    }
                } else {
                    print("❌ HueAPIClient: Массив ответов пуст")
                }
                
                throw HueAPIError.invalidResponse
            }
            .eraseToAnyPublisher()
    }
}

extension HueAPIClient {
    
    // MARK: - Исправление 1: Правильный endpoint для создания пользователя в API v2
    
    /// Создает нового пользователя (application key) на мосту - исправленная версия
    /// В API v2 используется endpoint /api с методом POST
    func createUserV2(appName: String, deviceName: String) -> AnyPublisher<AuthenticationResponse, Error> {
        guard let url = baseURL?.appendingPathComponent("/api") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // В API v2 используется другая структура
        let body: [String: Any] = [
            "devicetype": "\(appName)#\(deviceName)",
            "generateclientkey": true  // Для Entertainment API
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Проверяем статус ответа
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        return data
                    } else if httpResponse.statusCode == 101 {
                        // Link button not pressed
                        throw HueAPIError.linkButtonNotPressed
                    }
                }
                throw HueAPIError.invalidResponse
            }
            .decode(type: [AuthenticationResponse].self, decoder: JSONDecoder())
            .compactMap { $0.first }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Исправление 2: Правильные пути для API v2
    
    /// Базовые пути для различных типов запросов
    private var clipV2BasePath: String {
        guard let key = applicationKey else { return "" }
        return "/clip/v2/resource"
    }
    
    // MARK: - Исправление 3: Правильная обработка SSE
    
    /// Подключается к потоку событий - исправленная версия
    func connectToEventStreamV2() -> AnyPublisher<HueEvent, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        // Правильный URL для SSE в API v2
        guard let url = baseURL?.appendingPathComponent("/eventstream/clip/v2") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = TimeInterval.infinity
        
        // Добавляем keep-alive
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        return Future<HueEvent, Error> { [weak self] promise in
            self?.eventStreamTask = self?.session.dataTask(with: request)
            self?.eventStreamTask?.resume()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Исправление 4: Правильная структура для удаления ресурсов
    
    /// Удаляет ресурс
    func deleteResource<T: Decodable>(type: String, id: String) -> AnyPublisher<T, Error> {
        let endpoint = "/clip/v2/resource/\(type)/\(id)"
        return performRequestHTTPS<T>(endpoint: endpoint, method: "DELETE")
    }
    
    // MARK: - Исправление 5: Batch операции для оптимизации
    
    /// Выполняет batch операцию для множественных изменений
    func batchUpdate(updates: [BatchUpdate]) -> AnyPublisher<BatchResponse, Error> {
        let endpoint = "/clip/v2/resource"
        
        let body = BatchRequest(data: updates)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(body)
            
            return performRequestHTTPS<BatchResponse>(endpoint: endpoint, method: "PUT", body: data)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Исправление 6: Правильная работа с Entertainment Configuration
    
    /// Создает Entertainment Configuration
    func createEntertainmentConfiguration(
        name: String,
        lights: [String],
        positions: [Position3D]
    ) -> AnyPublisher<EntertainmentConfiguration, Error> {
        let endpoint = "/clip/v2/resource/entertainment_configuration"
        
        var config = EntertainmentConfiguration()
        config.metadata.name = name
        
        // Создаем каналы для каждой лампы
        config.channels = lights.enumerated().map { index, lightId in
            var channel = EntertainmentChannel()
            channel.channel_id = index
            channel.position = positions[safe: index] ?? Position3D(x: 0, y: 0, z: 0)
            channel.members = [
                ChannelMember(
                    service: ResourceIdentifier(rid: lightId, rtype: "light"),
                    index: 0
                )
            ]
            return channel
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(config)
            
            return performRequestHTTPS<EntertainmentConfiguration>(endpoint: endpoint, method: "POST", body: data)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    

}



// MARK: - ПРАВИЛЬНОЕ ИСПРАВЛЕНИЕ: API v2 через HTTPS

extension HueAPIClient {
    
    /// Правильный базовый URL для API v2 (ОБЯЗАТЕЛЬНО HTTPS)
    private var baseURLHTTPS: URL? {
        URL(string: "https://\(bridgeIP)")
    }
    
    /// ИСПРАВЛЕННАЯ версия performRequest для API v2 (HTTPS)
    private func performRequestHTTPS<T: Decodable>(
        endpoint: String,
        method: String,
        body: Data? = nil,
        authenticated: Bool = true
    ) -> AnyPublisher<T, Error> {
        
        guard authenticated else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let applicationKey = applicationKey else {
            print("❌ Нет application key для HTTPS запроса")
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = baseURLHTTPS?.appendingPathComponent(endpoint) else {
            print("❌ Невозможно создать HTTPS URL: endpoint=\(endpoint)")
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        print("📤 HTTPS \(method) запрос: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: API v2 использует hue-application-key header
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        print("🔑 Установлен hue-application-key: \(String(applicationKey.prefix(8)))...")
        
        if let body = body {
            request.httpBody = body
            if let bodyString = String(data: body, encoding: .utf8) {
                print("📦 HTTPS тело запроса: \(bodyString)")
            }
        }
        
        return sessionHTTPS.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ HTTPS ответ не является HTTP ответом")
                    throw HueAPIError.invalidResponse
                }
                
                print("📥 HTTPS \(httpResponse.statusCode) ответ от \(url.absoluteString)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 HTTPS тело ответа: \(responseString)")
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    print("❌ HTTPS ошибка \(httpResponse.statusCode)")
                    
                    switch httpResponse.statusCode {
                    case 401:
                        print("🔐 401 Unauthorized - проблема с application key")
                        throw HueAPIError.notAuthenticated
                    case 403:
                        print("🚫 403 Forbidden - возможно нужна повторная авторизация")
                        throw HueAPIError.linkButtonNotPressed
                    case 404:
                        print("🔍 404 Not Found - неверный endpoint API v2")
                        throw HueAPIError.invalidURL
                    case 503:
                        print("⚠️ 503 Service Unavailable - мост перегружен")
                        throw HueAPIError.bufferFull
                    case 429:
                        print("⏱ 429 Too Many Requests - превышен лимит")
                        throw HueAPIError.rateLimitExceeded
                    default:
                        break
                    }
                    
                    throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                }
                
                print("✅ HTTPS запрос успешен")
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
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
    
    /// Обогащает лампы v2 данными о reachable статусе из API v1
    private func enrichLightsWithReachableStatus(_ v2Lights: [Light]) -> AnyPublisher<[Light], Error> {
        print("🔗 Начинаем обогащение ламп статусом reachable...")
        
        // Получаем reachable статус через API v1
        return getLightsV1WithReachableStatus()
            .map { v1Lights in
                var enrichedLights = v2Lights
                
                print("📊 API v1: получено \(v1Lights.count) ламп для проверки статуса")
                
                for i in 0..<enrichedLights.count {
                    let v2Light = enrichedLights[i]
                    
                    // Ищем соответствующую лампу в v1 по различным критериям
                    let matchingV1Light = self.findMatchingV1Light(v2Light: v2Light, v1Lights: v1Lights)
                    
                    if let v1Light = matchingV1Light, let reachable = v1Light.state?.reachable {
                        // Устанавливаем статус связи на основе reachable поля
                        let newStatus: CommunicationStatus = reachable ? .online : .offline
                        enrichedLights[i].communicationStatus = newStatus
                        print("🔗 Лампа '\(v2Light.metadata.name)': reachable=\(reachable) → статус=\(newStatus)")
                    } else {
                        // Если не нашли в v1, оставляем неизвестный статус
                        enrichedLights[i].communicationStatus = .unknown
                        print("❓ Лампа '\(v2Light.metadata.name)': статус неизвестен (не найдена в API v1)")
                    }
                }
                
                let onlineCount = enrichedLights.filter { $0.communicationStatus == .online }.count
                let offlineCount = enrichedLights.filter { $0.communicationStatus == .offline }.count
                let unknownCount = enrichedLights.filter { $0.communicationStatus == .unknown }.count
                
                print("� Статистика статусов: online=\(onlineCount), offline=\(offlineCount), unknown=\(unknownCount)")
                
                return enrichedLights
            }
            .catch { error in
                print("⚠️ Не удалось получить reachable статус из v1: \(error)")
                // В случае ошибки возвращаем лампы v2 с неизвестным статусом
                var lightsWithUnknownStatus = v2Lights
                for i in 0..<lightsWithUnknownStatus.count {
                    lightsWithUnknownStatus[i].communicationStatus = .unknown
                    print("❓ Лампа '\(v2Lights[i].metadata.name)': статус установлен как unknown из-за ошибки API v1")
                }
                return Just(lightsWithUnknownStatus)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает данные ламп из API v1 с reachable полем
    func getLightsV1WithReachableStatus() -> AnyPublisher<[String: LightV1WithReachable], Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        print("📡 Запрос reachable статуса через API v1...")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        throw HueAPIError.bridgeNotFound
                    } else if httpResponse.statusCode >= 400 {
                        throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 v1 lights response: \(responseString.prefix(200))...")
                }
                
                return data
            }
            .decode(type: [String: LightV1WithReachable].self, decoder: JSONDecoder())
            .mapError { error in
                print("❌ Ошибка получения v1 lights: \(error)")
                return HueAPIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    /// Находит соответствующую лампу v1 для лампы v2
    func findMatchingV1Light(v2Light: Light, v1Lights: [String: LightV1WithReachable]) -> LightV1WithReachable? {
        // Метод 1: Поиск по имени (самый надежный)
        for (_, v1Light) in v1Lights {
            if let v1Name = v1Light.name, v1Name == v2Light.metadata.name {
                print("✅ Найдено соответствие по имени: \(v1Name)")
                return v1Light
            }
        }
        
        // Метод 2: Поиск по последним символам ID
        let v2IdSuffix = String(v2Light.id.suffix(6)).uppercased()
        for (v1Id, v1Light) in v1Lights {
            if v1Id.uppercased().contains(v2IdSuffix) {
                print("✅ Найдено соответствие по ID suffix: \(v1Id)")
                return v1Light
            }
        }
        
        // Метод 3: Поиск по uniqueid (если доступен)
        if let uniqueid = findUniqueIdFromV2Light(v2Light) {
            for (_, v1Light) in v1Lights {
                if let v1Uniqueid = v1Light.uniqueid, v1Uniqueid.contains(uniqueid) {
                    print("✅ Найдено соответствие по uniqueid: \(uniqueid)")
                    return v1Light
                }
            }
        }
        
        print("❌ Не найдено соответствие для лампы: \(v2Light.metadata.name)")
        return nil
    }
    
    /// Пытается извлечь uniqueid из данных v2 лампы
    private func findUniqueIdFromV2Light(_ light: Light) -> String? {
        // В API v2 uniqueid может быть спрятан в различных местах
        // Обычно это последняя часть ID лампы
        let lightId = light.id
        
        // Ищем части, похожие на MAC адрес
        let components = lightId.components(separatedBy: "-")
        for component in components {
            if component.count >= 6 && component.range(of: "^[0-9A-Fa-f]+$", options: .regularExpression) != nil {
                return component.uppercased()
            }
        }
        
        return nil
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
    

}




extension HueAPIClient {
    
    // MARK: - Структуры для маппинга серийных номеров
    
    /// Информация о сопоставлении устройства
    struct DeviceMapping {
        let deviceId: String        // RID устройства из API v2
        let serialNumber: String?   // Серийный номер с корпуса
        let uniqueId: String?       // Unique ID из API v1 (содержит MAC)
        let macAddress: String?     // Полный MAC/EUI-64 адрес
        let shortMac: String?       // Последние 3 байта MAC (для внутреннего использования)
        let lightId: String?        // ID лампы в системе
        let name: String            // Название лампы
    }
    
    // MARK: - Основной метод добавления лампы по серийному номеру
    
    /// Добавляет лампу по серийному номеру через правильный API flow
    // Файл: BulbsHUE/PhilipsHueV2/Network/HueAPIClient.swift
    // Обновите метод addLightBySerialNumber (строка ~2100)

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
    
    // MARK: - Получение маппинга устройств
    
    /// Получает полный маппинг всех устройств (серийники ↔ MAC ↔ lights)
    private func getDeviceMappings() -> AnyPublisher<[DeviceMapping], Error> {
        print("📊 Получаем маппинг устройств...")
        
        // Параллельно загружаем все необходимые данные
        let devicesPublisher = getV2Devices()
        let zigbeePublisher = getV2ZigbeeConnectivity()
        let v1LightsPublisher = getV1Lights()
        
        return Publishers.Zip3(devicesPublisher, zigbeePublisher, v1LightsPublisher)
            .map { devices, zigbeeConns, v1Lights in
                self.buildDeviceMappings(
                    devices: devices,
                    zigbeeConns: zigbeeConns,
                    v1Lights: v1Lights
                )
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает список устройств через API v2
       private func getV2Devices() -> AnyPublisher<[V2Device], Error> {
           let endpoint = "/clip/v2/resource/device"
           
           return performRequestHTTPS<V2DevicesResponse>(endpoint: endpoint, method: "GET")
               .map { (response: V2DevicesResponse) in
                   response.data
               }
               .eraseToAnyPublisher()
       }
    
    /// Получает Zigbee connectivity данные через API v2
    private func getV2ZigbeeConnectivity() -> AnyPublisher<[V2ZigbeeConn], Error> {
           let endpoint = "/clip/v2/resource/zigbee_connectivity"
           
           return performRequestHTTPS<V2ZigbeeResponse>(endpoint: endpoint, method: "GET")
               .map { (response: V2ZigbeeResponse) in
                   response.data
               }
               .eraseToAnyPublisher()
       }
    
    /// Получает список ламп через API v1 (для uniqueid)
    private func getV1Lights() -> AnyPublisher<[String: V1Light], Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [String: V1Light].self, decoder: JSONDecoder())
            .mapError { error in
                print("❌ Ошибка получения v1 lights: \(error)")
                return HueAPIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    /// Строит маппинг устройств из полученных данных
    private func buildDeviceMappings(
        devices: [V2Device],
        zigbeeConns: [V2ZigbeeConn],
        v1Lights: [String: V1Light]
    ) -> [DeviceMapping] {
        
        var mappings: [DeviceMapping] = []
        
        for device in devices {
            // Находим Zigbee connectivity для устройства
            let zigbee = zigbeeConns.first { $0.owner.rid == device.id }
            
            // Извлекаем ID лампы из id_v1
            let v1LightId = extractV1LightId(from: device.id_v1)
            
            // Находим данные из API v1
            let v1Light = v1LightId.flatMap { v1Lights[$0] }
            
            // Извлекаем короткий MAC из uniqueid
            let shortMac = extractShortMac(from: v1Light?.uniqueid)
            
            let mapping = DeviceMapping(
                deviceId: device.id,
                serialNumber: device.serial_number,
                uniqueId: v1Light?.uniqueid,
                macAddress: zigbee?.mac_address ?? zigbee?.mac,
                shortMac: shortMac,
                lightId: extractLightServiceId(from: device.services),
                name: device.metadata?.name ?? "Unknown"
            )
            
            mappings.append(mapping)
            
            // Логируем для отладки
            if let serial = mapping.serialNumber {
                print("📍 Устройство: \(mapping.name)")
                print("   Серийный номер: \(serial)")
                print("   MAC: \(mapping.macAddress ?? "н/д")")
                print("   Short MAC: \(mapping.shortMac ?? "н/д")")
            }
        }
        
        return mappings
    }
    
    // MARK: - Targeted Search (добавление новой лампы)
    
    /// Выполняет targeted search для добавления новой лампы
    private func performTargetedSearch(serialNumber: String) -> AnyPublisher<[Light], Error> {
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
    private func checkForNewLights() -> AnyPublisher<[Light], Error> {
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
    
    // MARK: - Helper методы
    
    /// Извлекает ID лампы v1 из id_v1
    private func extractV1LightId(from idV1: String?) -> String? {
        guard let idV1 = idV1 else { return nil }
        // "/lights/3" -> "3"
        return idV1.split(separator: "/").last.map(String.init)
    }
    
    /// Извлекает короткий MAC из uniqueid
    private func extractShortMac(from uniqueid: String?) -> String? {
        guard let uniqueid = uniqueid else { return nil }
        // "00:17:88:01:10:3e:5f:86-0b" -> "3e5f86"
        let macPart = uniqueid.split(separator: "-").first ?? ""
        let bytes = macPart.split(separator: ":")
        guard bytes.count >= 3 else { return nil }
        return bytes.suffix(3).joined().lowercased()
    }
    
    /// Извлекает ID light сервиса из списка сервисов
    private func extractLightServiceId(from services: [V2Service]?) -> String? {
        return services?.first { $0.rtype == "light" }?.rid
    }
}

// MARK: - Модели данных для API

/// Ответ API v2 для устройств
struct V2DevicesResponse: Codable {
    let data: [V2Device]
}

/// Устройство в API v2
struct V2Device: Codable {
    let id: String
    let id_v1: String?
    let serial_number: String?
    let metadata: V2Metadata?
    let services: [V2Service]
}

/// Метаданные устройства
struct V2Metadata: Codable {
    let name: String?
    let archetype: String?
}

/// Сервис устройства
struct V2Service: Codable {
    let rid: String
    let rtype: String
}

/// Ответ API v2 для Zigbee connectivity
struct V2ZigbeeResponse: Codable {
    let data: [V2ZigbeeConn]
}

/// Zigbee connectivity в API v2
struct V2ZigbeeConn: Codable {
    struct Owner: Codable {
        let rid: String
        let rtype: String
    }
    
    let id: String
    let owner: Owner
    let mac_address: String?
    let mac: String?
}

/// Лампа в API v1
struct V1Light: Codable {
    let name: String
    let uniqueid: String?
    let state: V1LightState
}

/// Состояние лампы в API v1
struct V1LightState: Codable {
    let on: Bool
    let bri: Int?
}


// MARK: - Safe Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Структуры для API v1 с reachable полем

/// Структура лампы из API v1 с полем reachable
struct LightV1WithReachable: Codable {
    let name: String?
    let uniqueid: String?
    let state: LightV1StateWithReachable?
    let type: String?
    let modelid: String?
    let manufacturername: String?
    let swversion: String?
}

/// Состояние лампы из API v1 с reachable полем
struct LightV1StateWithReachable: Codable {
    let on: Bool?
    let bri: Int?
    let hue: Int?
    let sat: Int?
    let reachable: Bool?  // КЛЮЧЕВОЕ ПОЛЕ для определения доступности
    let alert: String?
    let effect: String?
    let colormode: String?
    let ct: Int?
    let xy: [Double]?
}
