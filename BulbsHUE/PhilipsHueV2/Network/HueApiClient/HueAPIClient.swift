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
    internal let bridgeIP: String
    
    /// Application Key для авторизации в API
    /// В API v2 заменяет старое понятие "username"
    /// Должен храниться в безопасном месте
    internal var applicationKey: String?
    
    /// Сервис для персистентного хранения данных
    internal weak var dataPersistenceService: DataPersistenceService?
    
    /// Weak reference на LightsViewModel для обновления статуса связи
    internal weak var lightsViewModel: LightsViewModel?
    
    /// URLSession с настроенной проверкой сертификата
    /// Исправлено для iOS 17+ совместимости
    internal lazy var session: URLSession = {
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
    
    /// Специальная HTTPS сессия с правильной проверкой сертификата Hue Bridge
    internal lazy var sessionHTTPS: URLSession = {
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
    
    /// Базовый URL для API endpoint'ов
    /// Используем HTTP для локальных подключений, HTTPS только для удаленных
    internal var baseURL: URL? {
        // Для локальной сети используем HTTP (Hue Bridge поддерживает HTTP на порту 80)
        URL(string: "http://\(bridgeIP)")
    }
    
    /// Правильный базовый URL для API v2 (ОБЯЗАТЕЛЬНО HTTPS)
    internal var baseURLHTTPS: URL? {
        URL(string: "https://\(bridgeIP)")
    }
    
    /// Combine publisher для обработки ошибок
    internal let errorSubject = PassthroughSubject<HueAPIError, Never>()
    var errorPublisher: AnyPublisher<HueAPIError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    /// Publisher для Server-Sent Events
    internal let eventSubject = PassthroughSubject<HueEvent, Never>()
    var eventPublisher: AnyPublisher<HueEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Активная задача для SSE потока
    internal var eventStreamTask: URLSessionDataTask?
    
    /// Буфер для SSE данных
    internal var eventStreamBuffer = Data()
    
    /// Очередь для ограничения скорости запросов
    internal let throttleQueue = DispatchQueue(label: "com.hue.throttle", qos: .userInitiated)
    
    /// Время последнего запроса к lights
    internal var lastLightRequestTime = Date.distantPast
    
    /// Время последнего запроса к groups
    internal var lastGroupRequestTime = Date.distantPast
    
    /// Минимальный интервал между запросами к lights (100мс)
    internal let lightRequestInterval: TimeInterval = 0.1
    
    /// Минимальный интервал между запросами к groups (1с)
    internal let groupRequestInterval: TimeInterval = 1.0
    
    /// Набор подписок
    internal var cancellables = Set<AnyCancellable>()
    
    /// Базовые пути для различных типов запросов
    internal var clipV2BasePath: String {
        guard let key = applicationKey else { return "" }
        return "/clip/v2/resource"
    }
    
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
    
    /// Проверяет наличие валидного подключения к мосту
    func hasValidConnection() -> Bool {
        return applicationKey != nil && !bridgeIP.isEmpty
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient.swift
 
 Описание:
 Основной класс для работы с Philips Hue API v2. Содержит базовую конфигурацию,
 свойства и инициализацию клиента.
 
 Основные компоненты:
 - Конфигурация URLSession для HTTP/HTTPS запросов
 - Управление application key для авторизации
 - Publishers для событий и ошибок
 - Очереди для ограничения скорости запросов
 - Базовые URL для API endpoints
 
 Использование:
 let client = HueAPIClient(bridgeIP: "192.168.1.100")
 client.setApplicationKey("your-app-key")
 
 Зависимости:
 - SwiftUI, Combine, Network frameworks
 - DataPersistenceService для хранения данных
 - LightsViewModel для обновления UI
 
 Связанные файлы:
 - HueAPIClient+Authentication.swift - методы авторизации
 - HueAPIClient+Lights.swift - управление лампами
 - HueAPIClient+Networking.swift - сетевые запросы
 - HueAPIClient+SSE.swift - Server-Sent Events
 - HueAPIClient+Discovery.swift - поиск устройств
 - HueAPIClient+URLSessionDelegate.swift - делегат URL сессии
 */
