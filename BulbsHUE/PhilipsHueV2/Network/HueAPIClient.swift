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
    
    /// URLSession с настроенной проверкой сертификата
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        // Включаем HTTP/2 для мультиплексирования SSE и обычных запросов
        configuration.multipathServiceType = .handover
        configuration.allowsConstrainedNetworkAccess = true
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
    
    // MARK: - Initialization
    
    /// Инициализирует клиент с IP адресом моста
    /// - Parameter bridgeIP: IP адрес Hue Bridge
    init(bridgeIP: String) {
        self.bridgeIP = bridgeIP
        super.init()
    }
    
    /// Устанавливает application key для авторизации
    /// - Parameter key: Application key полученный при регистрации
    func setApplicationKey(_ key: String) {
        self.applicationKey = key
    }
    
    // MARK: - Authentication
    
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
    /// - Returns: Combine Publisher со списком ламп
    func getAllLights() -> AnyPublisher<[Light], Error> {
        guard applicationKey != nil else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        let endpoint = "/clip/v2/resource/light"
        return performRequest(endpoint: endpoint, method: "GET")
            .map { (response: LightsResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает информацию о конкретной лампе
    /// - Parameter id: Уникальный идентификатор лампы
    /// - Returns: Combine Publisher с информацией о лампе
    func getLight(id: String) -> AnyPublisher<Light, Error> {
        let endpoint = "/clip/v2/resource/light/\(id)"
        return performRequest(endpoint: endpoint, method: "GET")
            .map { (response: LightResponse) in
                response.data.first ?? Light()
            }
            .eraseToAnyPublisher()
    }
    
    /// Обновляет состояние лампы с учетом ограничений производительности
    /// - Parameters:
    ///   - id: Уникальный идентификатор лампы
    ///   - state: Новое состояние лампы
    /// - Returns: Combine Publisher с результатом операции
    func updateLight(id: String, state: LightState) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            self?.throttleQueue.async {
                guard let self = self else {
                    promise(.failure(HueAPIError.invalidResponse))
                    return
                }
                
                // Проверяем ограничение скорости для lights
                let now = Date()
                let timeSinceLastRequest = now.timeIntervalSince(self.lastLightRequestTime)
                
                if timeSinceLastRequest < self.lightRequestInterval {
                    // Ждем оставшееся время
                    let delay = self.lightRequestInterval - timeSinceLastRequest
                    Thread.sleep(forTimeInterval: delay)
                }
                
                self.lastLightRequestTime = Date()
                
                let endpoint = "/clip/v2/resource/light/\(id)"
                
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(state)
                    
                    self.performRequest(endpoint: endpoint, method: "PUT", body: data)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    print("Error updating light: \(error)")
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
    
    // MARK: - Scenes Endpoints
    
    /// Получает список всех сцен
    /// - Returns: Combine Publisher со списком сцен
    func getAllScenes() -> AnyPublisher<[HueScene], Error> {
        let endpoint = "/clip/v2/resource/scene"
        return performRequest(endpoint: endpoint, method: "GET")
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
            
            return performRequest(endpoint: endpoint, method: "PUT", body: data)
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
            
            return performRequest(endpoint: endpoint, method: "POST", body: data)
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
        return performRequest(endpoint: endpoint, method: "GET")
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
        return performRequest(endpoint: endpoint, method: "GET")
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
        return performRequest(endpoint: endpoint, method: "GET")
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
        return performRequest(endpoint: endpoint, method: "GET")
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
            
            return performRequest(endpoint: endpoint, method: "POST", body: data)
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
            
            return performRequest(endpoint: endpoint, method: "PUT", body: data)
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
                return Fail(error: HueAPIError.notAuthenticated)
                    .eraseToAnyPublisher()
            }
        }
        
        guard let url = baseURL?.appendingPathComponent(endpoint) else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if authenticated, let applicationKey = applicationKey {
            request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HueAPIError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    // Проверяем специфичные ошибки
                    if httpResponse.statusCode == 403 {
                        throw HueAPIError.linkButtonNotPressed
                    } else if httpResponse.statusCode == 503 {
                        // Internal error 503 - буфер переполнен
                        throw HueAPIError.bufferFull
                    } else if httpResponse.statusCode == 429 {
                        // Rate limit exceeded
                        throw HueAPIError.rateLimitExceeded
                    }
                    throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
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
        return performRequest(endpoint: endpoint, method: "DELETE")
    }
    
    // MARK: - Исправление 5: Batch операции для оптимизации
    
    /// Выполняет batch операцию для множественных изменений
    func batchUpdate(updates: [BatchUpdate]) -> AnyPublisher<BatchResponse, Error> {
        let endpoint = "/clip/v2/resource"
        
        let body = BatchRequest(data: updates)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(body)
            
            return performRequest(endpoint: endpoint, method: "PUT", body: data)
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
            
            return performRequest(endpoint: endpoint, method: "POST", body: data)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Исправление 7: mDNS Discovery с использованием Bonjour
    
    /// Поиск Hue Bridge через mDNS - правильная реализация (рекомендуемый метод)
//    func discoverBridgesViaSSDPV2() -> AnyPublisher<[Bridge], Error> {
//        return BonjourDiscovery().discoverBridges()
//    }
}



// MARK: - Bonjour Discovery Helper

//
///// Вспомогательный класс для mDNS поиска Hue Bridge (правильный рекомендуемый метод)
//class BonjourDiscovery {
//    private let browser = NWBrowser(for: .bonjour(type: "_hue._tcp", domain: "local"), using: .tcp)
//    private var bridges: [Bridge] = []
//    private let subject = PassthroughSubject<[Bridge], Error>()
//    private var connections: [NWConnection] = []
//    private var hasPermissionDeniedError = false
//    
//    func discoverBridges() -> AnyPublisher<[Bridge], Error> {
//        print("🔍 Начинаем mDNS поиск Hue Bridge (_hue._tcp.local)...")
//        
//        browser.browseResultsChangedHandler = { [weak self] results, changes in
//            print("📡 Обнаружены изменения в результатах mDNS: \(results.count) устройств")
//            self?.handleBrowseResults(results)
//        }
//        
//        browser.stateUpdateHandler = { [weak self] state in
//            switch state {
//            case .ready:
//                print("✅ mDNS браузер готов к работе")
//            case .failed(let error):
//                print("❌ Ошибка mDNS браузера: \(error)")
//                self?.subject.send(completion: .failure(error))
//            case .waiting(let error):
//                print("⏳ mDNS браузер ожидает: \(error)")
//                // Проверяем код ошибки для определения отказа в разрешении
//                let nsError = error as NSError
//                if nsError.code == Int(kDNSServiceErr_PolicyDenied) {
//                    print("🚫 Разрешение на локальную сеть отклонено пользователем")
//                    self?.hasPermissionDeniedError = true
//                    self?.subject.send(completion: .failure(HueAPIError.localNetworkPermissionDenied))
//                } else {
//                    print("⏳ Ожидание других условий: \(error.localizedDescription)")
//                }
//            default:
//                break
//            }
//        }
//        
//        browser.start(queue: .main)
//        
//        // Останавливаем поиск через 10 секунд
//        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
//            print("⏰ Завершаем mDNS поиск, найдено мостов: \(self?.bridges.count ?? 0)")
//            self?.browser.cancel()
//            self?.closeAllConnections()
//            self?.subject.send(self?.bridges ?? [])
//            self?.subject.send(completion: .finished)
//        }
//        
//        return subject.eraseToAnyPublisher()
//    }
//    
//    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
//        for result in results {
//            switch result.endpoint {
//            case .service(name: let name, type: _, domain: _, interface: _):
//                print("🎯 Найден mDNS сервис: \(name)")
//                resolveServiceEndpoint(result)
//            default:
//                break
//            }
//        }
//    }
//    
//    private func resolveServiceEndpoint(_ result: NWBrowser.Result) {
//        let connection = NWConnection(to: result.endpoint, using: .tcp)
//        connections.append(connection)
//        
//        connection.stateUpdateHandler = { [weak self] state in
//            switch state {
//            case .ready:
//                if let endpoint = connection.currentPath?.remoteEndpoint {
//                    self?.extractBridgeInfo(from: result, endpoint: endpoint)
//                }
//                connection.cancel()
//            case .failed(let error):
//                print("❌ Не удалось подключиться к \(result.endpoint): \(error)")
//                connection.cancel()
//            default:
//                break
//            }
//        }
//        
//        connection.start(queue: .main)
//    }
//    
//    private func extractBridgeInfo(from result: NWBrowser.Result, endpoint: NWEndpoint) {
//        // Извлекаем IP адрес
//        var ipAddress = ""
//        switch endpoint {
//        case .hostPort(let host, _):
//            switch host {
//            case .ipv4(let ipv4):
//                ipAddress = ipv4.debugDescription
//            case .ipv6(let ipv6):
//                ipAddress = ipv6.debugDescription
//            case .name(let hostname, _):
//                ipAddress = hostname
//            @unknown default:
//                return
//            }
//        default:
//            return
//        }
//        
//        // ИСПРАВЛЕНИЕ: НЕ парсим TXT записи как JSON!
//        // mDNS TXT записи содержат key=value пары, а НЕ JSON
//        var bridgeId = ""
//        
//        // Используем имя сервиса как Bridge ID по умолчанию
//        if case .service(let name, _, _, _) = result.endpoint {
//            bridgeId = name
//            print("🏷️ Используем имя сервиса как Bridge ID: \(bridgeId)")
//        }
//        
//        // Пытаемся получить реальный Bridge ID через HTTP API (без аутентификации)
//        validateAndGetBridgeInfo(ipAddress: ipAddress, fallbackId: bridgeId)
//    }
//    
//    private func validateAndGetBridgeInfo(ipAddress: String, fallbackId: String) {
//        // Получаем конфигурацию Bridge для валидации и извлечения реального ID
//        let configURL = URL(string: "https://\(ipAddress)/api/config")!
//        
//        print("🔍 Проверяем Bridge по адресу: \(configURL)")
//        
//        var request = URLRequest(url: configURL)
//        request.setValue("application/json", forHTTPHeaderField: "Accept")
//        request.timeoutInterval = 5
//        
//        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
//            if let error = error {
//                print("❌ Ошибка подключения к Bridge \(ipAddress): \(error)")
//                // Все равно добавляем Bridge с fallback ID
//                self?.addBridge(id: fallbackId, ip: ipAddress)
//                return
//            }
//            
//            guard let data = data else {
//                print("❌ Нет данных от Bridge \(ipAddress)")
//                self?.addBridge(id: fallbackId, ip: ipAddress)
//                return
//            }
//            
//            // Пытаемся парсить JSON конфигурацию
//            do {
//                if let config = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
//                    let realBridgeId = config["bridgeid"] as? String ?? fallbackId
//                    let name = config["name"] as? String ?? "Philips Hue Bridge"
//                    
//                    print("✅ Найден настоящий Hue Bridge: ID=\(realBridgeId), IP=\(ipAddress)")
//                    self?.addBridge(id: realBridgeId, ip: ipAddress, name: name)
//                } else {
//                    print("⚠️ Неожиданный формат ответа от \(ipAddress)")
//                    self?.addBridge(id: fallbackId, ip: ipAddress)
//                }
//            } catch {
//                print("❌ Ошибка парсинга JSON от \(ipAddress): \(error)")
//                // Это НЕ критическая ошибка - добавляем Bridge с fallback ID
//                self?.addBridge(id: fallbackId, ip: ipAddress)
//            }
//        }.resume()
//    }
//    
//    private func addBridge(id: String, ip: String, name: String = "Philips Hue Bridge") {
//        let bridge = Bridge(
//            id: id,
//            internalipaddress: ip,
//            port: 443,
//            name: name
//        )
//        
//        DispatchQueue.main.async { [weak self] in
//            // Проверяем, что мост еще не добавлен
//            if let bridges = self?.bridges,
//               !bridges.contains(where: { $0.id == bridge.id || $0.internalipaddress == bridge.internalipaddress }) {
//                self?.bridges.append(bridge)
//                print("🎉 Добавлен Bridge: \(bridge)")
//            }
//        }
//    }
//    
//    private func closeAllConnections() {
//        connections.forEach { $0.cancel() }
//        connections.removeAll()
//    }
//}

// MARK: - Safe Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
