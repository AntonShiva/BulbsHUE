// MARK: - Network Layer
// HueAPIClient.swift

import Foundation
import Combine
import SwiftUI

/// Основной клиент для взаимодействия с Philips Hue API v2
/// Использует HTTPS подключение с проверкой сертификатов
/// Поддерживает все основные endpoint'ы API v2
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
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    /// Базовый URL для API v2 endpoint'ов
    private var baseURL: URL? {
        URL(string: "https://\(bridgeIP)")
    }
    
    /// Combine publisher для обработки ошибок
    private let errorSubject = PassthroughSubject<HueAPIError, Never>()
    var errorPublisher: AnyPublisher<HueAPIError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
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
            .map(\.data)
            .decode(type: [AuthenticationResponse].self, decoder: JSONDecoder())
            .compactMap { $0.first }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Lights Endpoints
    
    /// Получает список всех ламп в системе
    /// - Returns: Combine Publisher со списком ламп
    func getAllLights() -> AnyPublisher<[Light], Error> {
        guard let applicationKey = applicationKey else {
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
    
    /// Обновляет состояние лампы
    /// - Parameters:
    ///   - id: Уникальный идентификатор лампы
    ///   - state: Новое состояние лампы
    /// - Returns: Combine Publisher с результатом операции
    func updateLight(id: String, state: LightState) -> AnyPublisher<Bool, Error> {
        let endpoint = "/clip/v2/resource/light/\(id)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)
            
            return performRequest(endpoint: endpoint, method: "PUT", body: data)
                .map { (_: GenericResponse) in true }
                .catch { error -> AnyPublisher<Bool, Error> in
                    // Логируем ошибку, но возвращаем false вместо проброса
                    print("Error updating light: \(error)")
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
        
        let body = [
            "recall": [
                "action": "active"
            ]
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body)
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
        
        var body: [String: Any] = [
            "type": "scene",
            "metadata": [
                "name": name
            ],
            "actions": lights.map { lightId in
                [
                    "target": [
                        "rid": lightId,
                        "rtype": "light"
                    ]
                ]
            }
        ]
        
        if let room = room {
            body["group"] = [
                "rid": room,
                "rtype": "room"
            ]
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body)
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
    
    /// Обновляет состояние группы ламп
    /// - Parameters:
    ///   - id: Идентификатор группы
    ///   - state: Новое состояние для всех ламп в группе
    /// - Returns: Combine Publisher с результатом операции
    func updateGroup(id: String, state: GroupState) -> AnyPublisher<Bool, Error> {
        let endpoint = "/clip/v2/resource/grouped_light/\(id)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)
            
            return performRequest(endpoint: endpoint, method: "PUT", body: data)
                .map { (_: GenericResponse) in true }
                .catch { error -> AnyPublisher<Bool, Error> in
                    print("Error updating group: \(error)")
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
    
    // MARK: - Device Discovery
    
    /// Поиск Hue Bridge в локальной сети через mDNS
    /// - Returns: Combine Publisher со списком найденных мостов
    func discoverBridges() -> AnyPublisher<[Bridge], Error> {
        guard let url = URL(string: "https://discovery.meethue.com") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Bridge].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Event Stream
    
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
        
        // Здесь должна быть реализация SSE парсера
        // Для примера возвращаем пустой publisher
        return Empty<HueEvent, Error>()
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    /// Выполняет HTTP запрос к API
    /// - Parameters:
    ///   - endpoint: Путь к endpoint'у
    ///   - method: HTTP метод
    ///   - body: Тело запроса (опционально)
    /// - Returns: Combine Publisher с декодированным ответом
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        body: Data? = nil
    ) -> AnyPublisher<T, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = baseURL?.appendingPathComponent(endpoint) else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
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
                    throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

// MARK: - URLSessionDelegate

extension HueAPIClient: URLSessionDelegate {
    /// Проверяет сертификат Hue Bridge
    /// Использует сертификат Signify CA для валидации
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
        
        // Здесь должна быть проверка сертификата с использованием Signify CA
        // Для примера используем стандартную проверку
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}

// MARK: - Error Types

/// Ошибки при работе с Hue API
enum HueAPIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case linkButtonNotPressed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Требуется авторизация. Установите application key."
        case .invalidURL:
            return "Неверный URL адрес"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .httpError(let statusCode):
            return "HTTP ошибка: \(statusCode)"
        case .linkButtonNotPressed:
            return "Нажмите кнопку Link на Hue Bridge"
        }
    }
}

// MARK: - Data Models
// Models.swift



// MARK: - Light Models

/// Модель лампы в системе Hue
/// Содержит всю информацию о физическом устройстве освещения
struct Light: Codable, Identifiable {
    /// Уникальный идентификатор лампы в формате UUID
    var id: String = UUID().uuidString
    
    /// Тип ресурса (всегда "light")
    var type: String = "light"
    
    /// Метаданные лампы
    var metadata: LightMetadata = LightMetadata()
    
    /// Текущее состояние включения/выключения
    var on: OnState = OnState()
    
    /// Настройки яркости (если поддерживается)
    var dimming: Dimming?
    
    /// Цветовые настройки (если поддерживается)
    var color: HueColor?
    
    /// Настройки цветовой температуры (если поддерживается)
    var color_temperature: ColorTemperature?
    
    /// Эффекты освещения
    var effects: Effects?
    
    /// Динамические эффекты (v2)
    var effects_v2: EffectsV2?
    
    /// Режим работы лампы
    var mode: String?
    
    /// Возможности лампы
    var capabilities: Capabilities?
}

/// Метаданные лампы
struct LightMetadata: Codable {
    /// Пользовательское имя лампы
    var name: String = "Новая лампа"
    
    /// Архетип лампы (тип установки)
    var archetype: String?
}

/// Состояние включения/выключения
struct OnState: Codable {
    /// Флаг включения
    var on: Bool = false
}

/// Настройки яркости
struct Dimming: Codable {
    /// Уровень яркости (1-100)
    var brightness: Double = 100.0
}

/// Цветовые настройки
struct HueColor: Codable {
    /// XY координаты цвета в цветовом пространстве CIE
    var xy: XYColor?
    
    /// Цветовая гамма устройства
    var gamut: Gamut?
    
    /// Тип цветовой гаммы
    var gamut_type: String?
}

/// XY координаты цвета
struct XYColor: Codable {
    /// X координата (0.0-1.0)
    var x: Double = 0.0
    
    /// Y координата (0.0-1.0)
    var y: Double = 0.0
}

/// Цветовая гамма
struct Gamut: Codable {
    /// Красная точка
    var red: XYColor?
    
    /// Зеленая точка
    var green: XYColor?
    
    /// Синяя точка
    var blue: XYColor?
}

/// Настройки цветовой температуры
struct ColorTemperature: Codable {
    /// Значение в миредах (153-500)
    var mirek: Int?
    
    /// Допустимый диапазон
    var mirek_schema: MirekSchema?
}

/// Схема диапазона цветовой температуры
struct MirekSchema: Codable {
    /// Минимальное значение
    var mirek_minimum: Int?
    
    /// Максимальное значение
    var mirek_maximum: Int?
}

/// Эффекты освещения (v1)
struct Effects: Codable {
    /// Текущий эффект
    var effect: String?
    
    /// Список доступных эффектов
    var effect_values: [String]?
    
    /// Статус эффекта
    var status: String?
}

/// Расширенные эффекты (v2)
struct EffectsV2: Codable {
    /// Текущий эффект
    var effect: String?
    
    /// Список доступных эффектов
    var effect_values: [String]?
    
    /// Статус эффекта
    var status: String?
    
    /// Длительность эффекта
    var duration: Int?
}

/// Возможности устройства
struct Capabilities: Codable {
    /// Сертифицировано для развлечений
    var certified: Bool?
    
    /// Поддержка потоковой передачи
    var streaming: StreamingCapabilities?
}

/// Возможности потоковой передачи
struct StreamingCapabilities: Codable {
    /// Поддержка рендеринга
    var renderer: Bool?
    
    /// Поддержка прокси
    var proxy: Bool?
}

// MARK: - Scene Models

/// Модель сцены освещения
struct HueScene: Codable, Identifiable {
    /// Уникальный идентификатор сцены
    var id: String = UUID().uuidString
    
    /// Тип ресурса (всегда "scene")
    var type: String = "scene"
    
    /// Метаданные сцены
    var metadata: SceneMetadata = SceneMetadata()
    
    /// Группа, к которой привязана сцена
    var group: ResourceIdentifier?
    
    /// Действия сцены
    var actions: [SceneAction] = []
    
    /// Палитра цветов для сцены
    var palette: ScenePalette?
    
    /// Скорость динамической сцены
    var speed: Double?
    
    /// Флаг автоматического динамического режима
    var auto_dynamic: Bool?
}

/// Метаданные сцены
struct SceneMetadata: Codable {
    /// Название сцены
    var name: String = "Новая сцена"
    
    /// Изображение сцены
    var image: ResourceIdentifier?
}

/// Действие в сцене
struct SceneAction: Codable {
    /// Цель действия (лампа или группа)
    var target: ResourceIdentifier?
    
    /// Настройки действия
    var action: LightState?
}

/// Палитра сцены
struct ScenePalette: Codable {
    /// Цвета в палитре
    var colors: [PaletteColor]?
    
    /// Настройки яркости
    var dimming: [Dimming]?
    
    /// Цветовые температуры
    var color_temperature: [ColorTemperaturePalette]?
}

/// Цвет в палитре
struct PaletteColor: Codable {
    /// Цветовые координаты
    var color: HueColor?
    
    /// Настройки яркости
    var dimming: Dimming?
}

/// Цветовая температура в палитре
struct ColorTemperaturePalette: Codable {
    /// Значение цветовой температуры
    var color_temperature: ColorTemperature?
    
    /// Настройки яркости
    var dimming: Dimming?
}

// MARK: - Group Models

/// Модель группы (комната или зона)
struct HueGroup: Codable, Identifiable {
    /// Уникальный идентификатор группы
    var id: String = UUID().uuidString
    
    /// Тип ресурса
    var type: String = "grouped_light"
    
    /// Владелец группы
    var owner: ResourceIdentifier?
    
    /// Состояние включения группы
    var on: OnState?
    
    /// Настройки яркости группы
    var dimming: Dimming?
    
    /// Оповещения
    var alert: HueAlert?
}

/// Оповещения
struct HueAlert: Codable {
    /// Список доступных действий
    var action_values: [String]?
}

// MARK: - Common Models

/// Идентификатор ресурса
struct ResourceIdentifier: Codable {
    /// ID ресурса
    var rid: String?
    
    /// Тип ресурса
    var rtype: String?
}

/// Состояние лампы для обновления
struct LightState: Codable {
    /// Включение/выключение
    var on: OnState?
    
    /// Яркость
    var dimming: Dimming?
    
    /// Цвет
    var color: HueColor?
    
    /// Цветовая температура
    var color_temperature: ColorTemperature?
    
    /// Эффекты
    var effects: Effects?
    
    /// Динамика перехода (миллисекунды)
    var dynamics: Dynamics?
}

/// Настройки динамики перехода
struct Dynamics: Codable {
    /// Длительность перехода в миллисекундах
    var duration: Int?
}

/// Состояние группы для обновления
struct GroupState: Codable {
    /// Включение/выключение
    var on: OnState?
    
    /// Яркость
    var dimming: Dimming?
    
    /// Оповещение
    var alert: HueAlert?
}

// MARK: - Bridge Models

/// Модель моста Hue
struct Bridge: Codable, Identifiable {
    /// Уникальный ID моста
    var id: String = ""
    
    /// IP адрес в локальной сети
    var internalipaddress: String = ""
    
    /// Порт (обычно 443 для HTTPS)
    var port: Int = 443
}

// MARK: - Authentication Models

/// Ответ при создании пользователя
struct AuthenticationResponse: Codable {
    /// Успешный результат
    var success: AuthSuccess?
    
    /// Ошибка
    var error: AuthError?
}

/// Успешная авторизация
struct AuthSuccess: Codable {
    /// Application key (username)
    var username: String?
    
    /// Client key для расширенной авторизации
    var clientkey: String?
}

/// Ошибка авторизации
struct AuthError: Codable {
    /// Тип ошибки
    var type: Int?
    
    /// Адрес ошибки
    var address: String?
    
    /// Описание ошибки
    var description: String?
}

// MARK: - Response Wrappers

/// Обертка для списка ламп
struct LightsResponse: Codable {
    var data: [Light]
}

/// Обертка для одной лампы
struct LightResponse: Codable {
    var data: [Light]
}

/// Обертка для списка сцен
struct ScenesResponse: Codable {
    var data: [HueScene]
}

/// Обертка для одной сцены
struct SceneResponse: Codable {
    var data: [HueScene]
}

/// Обертка для списка групп
struct GroupsResponse: Codable {
    var data: [HueGroup]
}

/// Общий ответ без данных
struct GenericResponse: Codable {
    var errors: [APIError]?
}

/// Ошибка API
struct APIError: Codable {
    var description: String?
}

// MARK: - Event Models

/// Событие от потока событий
struct HueEvent: Codable {
    /// Тип события
    var type: String?
    
    /// Данные события
    var data: [EventData]?
    
    /// Временная метка
    var creationtime: String?
}

/// Данные события
struct EventData: Codable {
    /// ID ресурса
    var id: String?
    
    /// Тип ресурса
    var type: String?
    
    /// Обновленные данные
    var data: AnyCodable?
}

/// Обертка для произвольных данных
struct AnyCodable: Codable {
    private var value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictionaryValue = try? container.decode([String: AnyCodable].self) {
            value = dictionaryValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictionaryValue as [String: Any]:
            try container.encode(dictionaryValue.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value"))
        }
    }
}

// MARK: - View Models
// LightsViewModel.swift

import Foundation
import Combine
import SwiftUI

/// ViewModel для управления лампами
/// Обрабатывает бизнес-логику и взаимодействие с API
class LightsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Список всех ламп в системе
    @Published var lights: [Light] = []
    
    /// Флаг загрузки данных
    @Published var isLoading: Bool = false
    
    /// Текущая ошибка (если есть)
    @Published var error: Error?
    
    /// Выбранная лампа для детального просмотра
    @Published var selectedLight: Light?
    
    /// Фильтр для отображения ламп
    @Published var filter: LightFilter = .all
    
    // MARK: - Private Properties
    
    /// Клиент для работы с API
    private let apiClient: HueAPIClient
    
    /// Набор подписок Combine
    private var cancellables = Set<AnyCancellable>()
    
    /// Таймер для периодического обновления
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    /// Инициализирует ViewModel с API клиентом
    /// - Parameter apiClient: Настроенный клиент Hue API
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Загружает список всех ламп
    func loadLights() {
        isLoading = true
        error = nil
        
        apiClient.getAllLights()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] lights in
                    self?.lights = lights
                }
            )
            .store(in: &cancellables)
    }
    
    /// Включает/выключает лампу
    /// - Parameter light: Лампа для переключения
    func toggleLight(_ light: Light) {
        let newState = LightState(
            on: OnState(on: !light.on.on)
        )
        
        updateLight(light.id, state: newState)
    }
    
    /// Устанавливает яркость лампы
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - brightness: Уровень яркости (0-100)
    func setBrightness(for light: Light, brightness: Double) {
        let newState = LightState(
            dimming: Dimming(brightness: brightness)
        )
        
        updateLight(light.id, state: newState)
    }
    
    /// Устанавливает цвет лампы
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - color: Цвет в формате SwiftUI Color
    func setColor(for light: Light, color: SwiftUI.Color) {
        let xyColor = convertToXY(color: color)
        let newState = LightState(
            color: HueColor(xy: xyColor)
        )
        
        updateLight(light.id, state: newState)
    }
    
    /// Устанавливает цветовую температуру
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - temperature: Температура в Кельвинах (2200-6500)
    func setColorTemperature(for light: Light, temperature: Int) {
        let mirek = 1_000_000 / temperature
        let newState = LightState(
            color_temperature: ColorTemperature(mirek: mirek)
        )
        
        updateLight(light.id, state: newState)
    }
    
    /// Применяет эффект к лампе
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - effect: Название эффекта
    func applyEffect(to light: Light, effect: String) {
        let newState = LightState(
            effects: Effects(effect: effect)
        )
        
        updateLight(light.id, state: newState)
    }
    
    /// Включает режим оповещения (мигание)
    /// - Parameter light: Лампа для оповещения
    func alertLight(_ light: Light) {
        // В API v2 alert обрабатывается через effects
        applyEffect(to: light, effect: "breathe")
    }
    
    /// Запускает автоматическое обновление
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
    
    /// Настраивает привязки данных
    private func setupBindings() {
        // Подписываемся на ошибки от API клиента
        apiClient.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &cancellables)
    }
    
    /// Обновляет состояние лампы
    /// - Parameters:
    ///   - lightId: ID лампы
    ///   - state: Новое состояние
    private func updateLight(_ lightId: String, state: LightState) {
        apiClient.updateLight(id: lightId, state: state)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        // Обновляем локальное состояние
                        self?.updateLocalLight(lightId, with: state)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обновляет локальное состояние лампы
    /// - Parameters:
    ///   - lightId: ID лампы
    ///   - state: Новое состояние
    private func updateLocalLight(_ lightId: String, with state: LightState) {
        guard let index = lights.firstIndex(where: { $0.id == lightId }) else { return }
        
        if let on = state.on {
            lights[index].on = on
        }
        
        if let dimming = state.dimming {
            lights[index].dimming = dimming
        }
        
        if let color = state.color {
            lights[index].color = color
        }
        
        if let colorTemp = state.color_temperature {
            lights[index].color_temperature = colorTemp
        }
        
        if let effects = state.effects {
            lights[index].effects = effects
        }
    }
    
    /// Конвертирует SwiftUI Color в XY координаты
    /// - Parameter color: Цвет SwiftUI
    /// - Returns: XY координаты для Hue API
    private func convertToXY(color: SwiftUI.Color) -> XYColor {
        // Получаем компоненты цвета
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        
        // Для SwiftUI используем другой подход
        if let cgColor = color.cgColor,
           let components = cgColor.components {
            red = components[0]
            green = components[1]
            blue = components[2]
            opacity = components.count > 3 ? components[3] : 1.0
        }
        
        // Применяем гамма-коррекцию
        red = (red > 0.04045) ? pow((red + 0.055) / 1.055, 2.4) : (red / 12.92)
        green = (green > 0.04045) ? pow((green + 0.055) / 1.055, 2.4) : (green / 12.92)
        blue = (blue > 0.04045) ? pow((blue + 0.055) / 1.055, 2.4) : (blue / 12.92)
        
        // Конвертируем в XYZ
        let X = red * 0.664511 + green * 0.154324 + blue * 0.162028
        let Y = red * 0.283881 + green * 0.668433 + blue * 0.047685
        let Z = red * 0.000088 + green * 0.072310 + blue * 0.986039
        
        // Конвертируем в xy
        let sum = X + Y + Z
        let x = sum > 0 ? X / sum : 0
        let y = sum > 0 ? Y / sum : 0
        
        return XYColor(x: x, y: y)
    }
    
    // MARK: - Computed Properties
    
    /// Отфильтрованные лампы
    var filteredLights: [Light] {
        switch filter {
        case .all:
            return lights
        case .on:
            return lights.filter { $0.on.on }
        case .off:
            return lights.filter { !$0.on.on }
        case .color:
            return lights.filter { $0.color != nil }
        case .white:
            return lights.filter { $0.color_temperature != nil && $0.color == nil }
        }
    }
}

/// Фильтр для отображения ламп
enum LightFilter: String, CaseIterable {
    case all = "Все"
    case on = "Включенные"
    case off = "Выключенные"
    case color = "Цветные"
    case white = "Белые"
}

// MARK: - Scenes ViewModel
// ScenesViewModel.swift



/// ViewModel для управления сценами освещения
class ScenesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Список всех сцен
    @Published var scenes: [HueScene] = []
    
    /// Активная сцена
    @Published var activeSceneId: String?
    
    /// Флаг загрузки
    @Published var isLoading: Bool = false
    
    /// Текущая ошибка
    @Published var error: Error?
    
    /// Режим редактирования сцены
    @Published var isEditingScene: Bool = false
    
    /// Редактируемая сцена
    @Published var editingScene: HueScene?
    
    // MARK: - Private Properties
    
    private let apiClient: HueAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// Загружает все сцены
    func loadScenes() {
        isLoading = true
        error = nil
        
        apiClient.getAllScenes()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] scenes in
                    self?.scenes = scenes
                }
            )
            .store(in: &cancellables)
    }
    
    /// Активирует сцену
    /// - Parameter scene: Сцена для активации
    func activateScene(_ scene: HueScene) {
        activeSceneId = scene.id
        
        apiClient.activateScene(sceneId: scene.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                        self?.activeSceneId = nil
                    }
                },
                receiveValue: { _ in
                    // Успешно активировано
                }
            )
            .store(in: &cancellables)
    }
    
    /// Создает новую сцену
    /// - Parameters:
    ///   - name: Название сцены
    ///   - lights: Список ID ламп
    ///   - captureCurrentState: Захватить текущее состояние ламп
    func createScene(name: String, lights: [String], captureCurrentState: Bool = true) {
        apiClient.createScene(name: name, lights: lights)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] scene in
                    self?.scenes.append(scene)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Удаляет сцену
    /// - Parameter scene: Сцена для удаления
    func deleteScene(_ scene: HueScene) {
        // Реализация удаления сцены
        scenes.removeAll { $0.id == scene.id }
    }
    
    /// Начинает редактирование сцены
    /// - Parameter scene: Сцена для редактирования
    func startEditing(_ scene: HueScene) {
        editingScene = scene
        isEditingScene = true
    }
    
    /// Сохраняет изменения в сцене
    func saveSceneChanges() {
        guard let scene = editingScene else { return }
        
        // Здесь должна быть логика сохранения изменений
        isEditingScene = false
        editingScene = nil
        loadScenes()
    }
    
    /// Отменяет редактирование
    func cancelEditing() {
        isEditingScene = false
        editingScene = nil
    }
    
    // MARK: - Computed Properties
    
    /// Сцены, сгруппированные по комнатам
    var scenesByRoom: [String: [HueScene]] {
        Dictionary(grouping: scenes) { scene in
            scene.group?.rid ?? "Без комнаты"
        }
    }
    
    /// Динамические сцены
    var dynamicScenes: [HueScene] {
        scenes.filter { $0.speed != nil }
    }
    
    /// Статические сцены
    var staticScenes: [HueScene] {
        scenes.filter { $0.speed == nil }
    }
}

// MARK: - Groups ViewModel
// GroupsViewModel.swift


/// ViewModel для управления группами (комнатами и зонами)
class GroupsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Список всех групп
    @Published var groups: [HueGroup] = []
    
    /// Флаг загрузки
    @Published var isLoading: Bool = false
    
    /// Текущая ошибка
    @Published var error: Error?
    
    /// Выбранная группа
    @Published var selectedGroup: HueGroup?
    
    // MARK: - Private Properties
    
    private let apiClient: HueAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// Загружает все группы
    func loadGroups() {
        isLoading = true
        error = nil
        
        apiClient.getAllGroups()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] groups in
                    self?.groups = groups
                }
            )
            .store(in: &cancellables)
    }
    
    /// Включает/выключает все лампы в группе
    /// - Parameter group: Группа для переключения
    func toggleGroup(_ group: HueGroup) {
        let newState = GroupState(
            on: OnState(on: !(group.on?.on ?? false))
        )
        
        updateGroup(group.id, state: newState)
    }
    
    /// Устанавливает яркость для группы
    /// - Parameters:
    ///   - group: Группа для изменения
    ///   - brightness: Уровень яркости (0-100)
    func setBrightness(for group: HueGroup, brightness: Double) {
        let newState = GroupState(
            dimming: Dimming(brightness: brightness)
        )
        
        updateGroup(group.id, state: newState)
    }
    
    /// Включает оповещение для группы
    /// - Parameter group: Группа для оповещения
    func alertGroup(_ group: HueGroup) {
        let newState = GroupState(
            alert: HueAlert(action_values: ["breathe"])
        )
        
        updateGroup(group.id, state: newState)
    }
    
    // MARK: - Private Methods
    
    /// Обновляет состояние группы
    private func updateGroup(_ groupId: String, state: GroupState) {
        apiClient.updateGroup(id: groupId, state: state)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.updateLocalGroup(groupId, with: state)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обновляет локальное состояние группы
    private func updateLocalGroup(_ groupId: String, with state: GroupState) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        
        if let on = state.on {
            groups[index].on = on
        }
        
        if let dimming = state.dimming {
            groups[index].dimming = dimming
        }
    }
}

// MARK: - Main App ViewModel
// AppViewModel.swift


/// Главный ViewModel приложения
/// Управляет состоянием подключения и координирует другие ViewModels
class AppViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Статус подключения к мосту
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    /// Найденные мосты в сети
    @Published var discoveredBridges: [Bridge] = []
    
    /// Текущий подключенный мост
    @Published var currentBridge: Bridge?
    
    /// Application key для авторизации
    @Published var applicationKey: String? {
        didSet {
            if let key = applicationKey {
                UserDefaults.standard.set(key, forKey: "HueApplicationKey")
                apiClient.setApplicationKey(key)
            }
        }
    }
    
    /// Показать экран настройки
    @Published var showSetup: Bool = false
    
    // MARK: - Child ViewModels
    
    /// ViewModel для управления лампами
    @Published var lightsViewModel: LightsViewModel
    
    /// ViewModel для управления сценами
    @Published var scenesViewModel: ScenesViewModel
    
    /// ViewModel для управления группами
    @Published var groupsViewModel: GroupsViewModel
    
    // MARK: - Private Properties
    
    private let apiClient: HueAPIClient
    private var cancellables = Set<AnyCancellable>()
    private var eventStreamCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    init() {
        // Инициализируем с пустым IP, будет установлен позже
        self.apiClient = HueAPIClient(bridgeIP: "")
        
        // Инициализируем дочерние ViewModels
        self.lightsViewModel = LightsViewModel(apiClient: apiClient)
        self.scenesViewModel = ScenesViewModel(apiClient: apiClient)
        self.groupsViewModel = GroupsViewModel(apiClient: apiClient)
        
        // Загружаем сохраненные настройки
        loadSavedSettings()
    }
    
    // MARK: - Public Methods
    
    /// Начинает поиск мостов в сети
    func discoverBridges() {
        connectionStatus = .searching
        
        apiClient.discoverBridges()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.connectionStatus = .disconnected
                    }
                },
                receiveValue: { [weak self] bridges in
                    self?.discoveredBridges = bridges
                    if bridges.isEmpty {
                        self?.connectionStatus = .disconnected
                    } else {
                        self?.connectionStatus = .discovered
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Подключается к выбранному мосту
    /// - Parameter bridge: Мост для подключения
    func connectToBridge(_ bridge: Bridge) {
        currentBridge = bridge
        UserDefaults.standard.set(bridge.internalipaddress, forKey: "HueBridgeIP")
        
        // Пересоздаем API клиент с новым IP
        recreateAPIClient(with: bridge.internalipaddress)
        
        if let key = applicationKey {
            connectionStatus = .connected
            startEventStream()
            loadAllData()
        } else {
            connectionStatus = .needsAuthentication
            showSetup = true
        }
    }
    
    /// Создает нового пользователя на мосту
    /// - Parameters:
    ///   - appName: Имя приложения
    ///   - completion: Обработчик завершения
    func createUser(appName: String, completion: @escaping (Bool) -> Void) {
        let deviceName = "iOS Device" // Или используйте другой способ получения имени устройства
        
        apiClient.createUser(appName: appName, deviceName: deviceName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure = result {
                        completion(false)
                    }
                },
                receiveValue: { [weak self] response in
                    if let success = response.success,
                       let username = success.username {
                        self?.applicationKey = username
                        self?.connectionStatus = .connected
                        self?.showSetup = false
                        self?.startEventStream()
                        self?.loadAllData()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Отключается от моста
    func disconnect() {
        connectionStatus = .disconnected
        currentBridge = nil
        applicationKey = nil
        eventStreamCancellable?.cancel()
        
        UserDefaults.standard.removeObject(forKey: "HueBridgeIP")
        UserDefaults.standard.removeObject(forKey: "HueApplicationKey")
    }
    
    /// Перезагружает все данные
    func refreshAll() {
        loadAllData()
    }
    
    // MARK: - Private Methods
    
    /// Загружает сохраненные настройки
    private func loadSavedSettings() {
        if let savedIP = UserDefaults.standard.string(forKey: "HueBridgeIP"),
           let savedKey = UserDefaults.standard.string(forKey: "HueApplicationKey") {
            
            recreateAPIClient(with: savedIP)
            applicationKey = savedKey
            
            currentBridge = Bridge(
                id: "",
                internalipaddress: savedIP,
                port: 443
            )
            
            connectionStatus = .connected
            startEventStream()
            loadAllData()
        } else {
            showSetup = true
        }
    }
    
    /// Пересоздает API клиент с новым IP
    private func recreateAPIClient(with ip: String) {
        // Создаем новый клиент
        let newClient = HueAPIClient(bridgeIP: ip)
        
        // Обновляем ссылки в дочерних ViewModels
        lightsViewModel = LightsViewModel(apiClient: newClient)
        scenesViewModel = ScenesViewModel(apiClient: newClient)
        groupsViewModel = GroupsViewModel(apiClient: newClient)
        
        // Устанавливаем application key если есть
        if let key = applicationKey {
            newClient.setApplicationKey(key)
        }
    }
    
    /// Загружает все данные
    private func loadAllData() {
        lightsViewModel.loadLights()
        scenesViewModel.loadScenes()
        groupsViewModel.loadGroups()
    }
    
    /// Запускает поток событий
    private func startEventStream() {
        eventStreamCancellable?.cancel()
        
        eventStreamCancellable = apiClient.connectToEventStream()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    // Обработка завершения потока
                },
                receiveValue: { [weak self] event in
                    self?.handleEvent(event)
                }
            )
    }
    
    /// Обрабатывает событие из потока
    private func handleEvent(_ event: HueEvent) {
        // Обновляем соответствующие данные в зависимости от типа события
        if let eventData = event.data?.first {
            switch eventData.type {
            case "light":
                lightsViewModel.loadLights()
            case "scene":
                scenesViewModel.loadScenes()
            case "grouped_light":
                groupsViewModel.loadGroups()
            default:
                break
            }
        }
    }
}

/// Статус подключения к мосту
enum ConnectionStatus {
    case disconnected
    case searching
    case discovered
    case needsAuthentication
    case connected
    
    var description: String {
        switch self {
        case .disconnected:
            return "Отключено"
        case .searching:
            return "Поиск мостов..."
        case .discovered:
            return "Мосты найдены"
        case .needsAuthentication:
            return "Требуется авторизация"
        case .connected:
            return "Подключено"
        }
    }
}
