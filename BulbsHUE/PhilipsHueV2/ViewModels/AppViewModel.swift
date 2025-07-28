

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

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
    
    /// Информация о возможностях моста
    @Published var bridgeCapabilities: BridgeCapabilities?
    
    /// Показатели производительности
    @Published var performanceMetrics = PerformanceMetrics()
    
    /// Текущая ошибка (если есть)
    @Published var error: Error?
    
    // MARK: - Child ViewModels
    
    /// ViewModel для управления лампами
    @Published var lightsViewModel: LightsViewModel
    
    /// ViewModel для управления сценами
    @Published var scenesViewModel: ScenesViewModel
    
    /// ViewModel для управления группами
    @Published var groupsViewModel: GroupsViewModel
    
    /// ViewModel для управления сенсорами
    @Published var sensorsViewModel: SensorsViewModel
    
    /// ViewModel для управления правилами
    @Published var rulesViewModel: RulesViewModel
    
    // MARK: - Private Properties
    
    private var apiClient: HueAPIClient
    private var cancellables = Set<AnyCancellable>()
    private var eventStreamCancellable: AnyCancellable?
    
    /// Клиент для Entertainment API
    private var entertainmentClient: HueEntertainmentClient?
    
    // MARK: - Initialization
    
    init() {
        // Инициализируем с пустым IP, будет установлен позже
        self.apiClient = HueAPIClient(bridgeIP: "")
        
        // Инициализируем дочерние ViewModels
        self.lightsViewModel = LightsViewModel(apiClient: apiClient)
        self.scenesViewModel = ScenesViewModel(apiClient: apiClient)
        self.groupsViewModel = GroupsViewModel(apiClient: apiClient)
        self.sensorsViewModel = SensorsViewModel(apiClient: apiClient)
        self.rulesViewModel = RulesViewModel(apiClient: apiClient)
        
        // Настраиваем мониторинг производительности
        setupPerformanceMonitoring()
        
        // Загружаем сохраненные настройки
        loadSavedSettings()
    }
    
    // MARK: - Public Methods
    
    /// Начинает поиск мостов в сети
    func discoverBridges() {
        connectionStatus = .searching
        
        // Пробуем оба метода параллельно
        let cloudDiscovery = apiClient.discoverBridgesViaCloud()
        let mdnsDiscovery = apiClient.discoverBridgesViaMDNS()
        
        Publishers.Merge(cloudDiscovery, mdnsDiscovery)
            .collect()
            .map { results in
                Array(Set(results.flatMap { $0 }))
            }
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
        
        // Проверяем конфигурацию моста
        apiClient.getBridgeConfig()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.connectionStatus = .disconnected
                    }
                },
                receiveValue: { [weak self] config in
                    // Проверяем версию API
                    if let apiVersion = config.apiversion,
                       apiVersion.compare("1.46.0", options: .numeric) == .orderedAscending {
                        self?.error = HueAPIError.outdatedBridge
                        return
                    }
                    
                    // Сохраняем ID моста для проверки сертификата
                    if let bridgeId = config.bridgeid {
                        self?.currentBridge?.id = bridgeId
                    }
                    
                    if let key = self?.applicationKey {
                        self?.connectionStatus = .connected
                        self?.startEventStream()
                        self?.loadAllData()
                    } else {
                        self?.connectionStatus = .needsAuthentication
                        self?.showSetup = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Создает нового пользователя на мосту
    /// - Parameters:
    ///   - appName: Имя приложения
    ///   - completion: Обработчик завершения
    func createUser(appName: String, completion: @escaping (Bool) -> Void) {
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        
        apiClient.createUser(appName: appName, deviceName: deviceName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        // Проверяем специфичную ошибку кнопки
                        if case HueAPIError.linkButtonNotPressed = error {
                            completion(false)
                        } else {
                            completion(false)
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    if let success = response.success,
                       let username = success.username {
                        self?.applicationKey = username
                        // Сохраняем client key для Entertainment API
                        if let clientKey = success.clientkey {
                            UserDefaults.standard.set(clientKey, forKey: "HueClientKey")
                            self?.setupEntertainmentClient(clientKey: clientKey)
                        }
                        self?.connectionStatus = .connected
                        self?.showSetup = false
                        self?.startEventStream()
                        self?.loadAllData()
                        completion(true)
                    } else if let error = response.error {
                        // Проверяем код ошибки 101 - кнопка не нажата
                        if error.type == 101 {
                            self?.error = HueAPIError.linkButtonNotPressed
                        }
                        completion(false)
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
    
    /// Загружает информацию о возможностях моста
    func loadBridgeCapabilities() {
        apiClient.getBridgeCapabilities()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] capabilities in
                    self?.bridgeCapabilities = capabilities
                    self?.checkResourceLimits(capabilities)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    /// Загружает сохраненные настройки
    private func loadSavedSettings() {
        if let savedIP = UserDefaults.standard.string(forKey: "HueBridgeIP"),
           let savedKey = UserDefaults.standard.string(forKey: "HueApplicationKey") {
            
            recreateAPIClient(with: savedIP)
            applicationKey = savedKey
            
            // Загружаем client key для Entertainment API
            if let clientKey = UserDefaults.standard.string(forKey: "HueClientKey") {
                setupEntertainmentClient(clientKey: clientKey)
            }
            
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
        apiClient = HueAPIClient(bridgeIP: ip)
        
        // Обновляем ссылки в дочерних ViewModels
        lightsViewModel = LightsViewModel(apiClient: apiClient)
        scenesViewModel = ScenesViewModel(apiClient: apiClient)
        groupsViewModel = GroupsViewModel(apiClient: apiClient)
        sensorsViewModel = SensorsViewModel(apiClient: apiClient)
        rulesViewModel = RulesViewModel(apiClient: apiClient)
        
        // Устанавливаем application key если есть
        if let key = applicationKey {
            apiClient.setApplicationKey(key)
        }
    }
    
    /// Загружает все данные
    private func loadAllData() {
        lightsViewModel.loadLights()
        scenesViewModel.loadScenes()
        groupsViewModel.loadGroups()
        sensorsViewModel.loadSensors()
        rulesViewModel.loadRules()
        loadBridgeCapabilities()
    }
    
    /// Запускает поток событий
    private func startEventStream() {
        eventStreamCancellable?.cancel()
        
        // Запускаем поток событий для всех ViewModels
        lightsViewModel.startEventStream()
        
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
        // События уже обрабатываются в дочерних ViewModels через eventPublisher
        performanceMetrics.eventsReceived += 1
    }
    
    /// Проверяет лимиты ресурсов
    private func checkResourceLimits(_ capabilities: BridgeCapabilities) {
        guard let limits = capabilities.resources else { return }
        
        // Проверяем приближение к лимитам
        if let lightLimit = limits.lights,
           lightsViewModel.lights.count > Int(Double(lightLimit) * 0.8) {
            print("Предупреждение: Используется более 80% доступных ламп")
        }
        
        if let ruleLimit = limits.rules,
           rulesViewModel.rules.count > Int(Double(ruleLimit) * 0.8) {
            print("Предупреждение: Используется более 80% доступных правил")
        }
        
        if let sceneLimit = limits.scenes,
           scenesViewModel.scenes.count > Int(Double(sceneLimit) * 0.8) {
            print("Предупреждение: Используется более 80% доступных сцен")
        }
    }
    
    /// Настраивает Entertainment клиент
    private func setupEntertainmentClient(clientKey: String) {
        guard let bridge = currentBridge else { return }
        entertainmentClient = HueEntertainmentClient(
            bridgeIP: bridge.internalipaddress,
            applicationKey: applicationKey ?? "",
            clientKey: clientKey
        )
    }
    
    /// Настраивает мониторинг производительности
    private func setupPerformanceMonitoring() {
        // Мониторинг ошибок производительности
        apiClient.errorPublisher
            .sink { [weak self] error in
                switch error {
                case .rateLimitExceeded:
                    self?.performanceMetrics.rateLimitHits += 1
                case .bufferFull:
                    self?.performanceMetrics.bufferOverflows += 1
                default:
                    break
                }
            }
            .store(in: &cancellables)
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

/// Метрики производительности
struct PerformanceMetrics {
    var eventsReceived: Int = 0
    var rateLimitHits: Int = 0
    var bufferOverflows: Int = 0
    var averageLatency: Double = 0
    
    mutating func reset() {
        eventsReceived = 0
        rateLimitHits = 0
        bufferOverflows = 0
        averageLatency = 0
    }
}
