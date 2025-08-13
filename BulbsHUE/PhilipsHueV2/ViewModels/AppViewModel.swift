

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
    
    /// Сервис для персистентного хранения данных
    private weak var dataPersistenceService: DataPersistenceService?
    
    /// Публичный доступ к DataPersistenceService для других компонентов
    var dataService: DataPersistenceService? {
        return dataPersistenceService
    }
    
    // MARK: - Initialization
    
    init(dataPersistenceService: DataPersistenceService? = nil) {
        self.dataPersistenceService = dataPersistenceService
        
        // Инициализируем с пустым IP, будет установлен позже
        self.apiClient = HueAPIClient(bridgeIP: "", dataPersistenceService: dataPersistenceService)
        
        // Инициализируем дочерние ViewModels
        self.lightsViewModel = LightsViewModel(apiClient: apiClient)
        self.scenesViewModel = ScenesViewModel(apiClient: apiClient)
        self.groupsViewModel = GroupsViewModel(apiClient: apiClient)
        self.sensorsViewModel = SensorsViewModel(apiClient: apiClient)
        self.rulesViewModel = RulesViewModel(apiClient: apiClient)
        
        // Настраиваем мониторинг производительности
        setupPerformanceMonitoring()
        
        // Настраиваем наблюдение за состоянием приложения
        setupAppStateObservation()
        
        // Загружаем сохраненные настройки
        loadSavedSettings()
    }
    
    // MARK: - Public Methods
    

    
    /// Начинает комплексный поиск мостов с использованием всех доступных методов
    func searchForBridges() {
        print("🚀 Запуск поиска мостов...")
        connectionStatus = .searching
        discoveredBridges.removeAll() // Очищаем предыдущие результаты
        error = nil // Сбрасываем предыдущие ошибки
        
        // ИСПРАВЛЕНИЕ: SSDP недоступен без multicast entitlement
        // Используем Cloud Discovery и IP scan (не требуют специальных entitlements)
        if #available(iOS 14.0, *) {
            let permissionChecker = LocalNetworkPermissionChecker()
            Task {
                do {
                    let hasPermission = try await permissionChecker.requestAuthorization()
                    await MainActor.run {
                        if hasPermission {
                            self.startDiscoveryProcess()
                        } else {
                            print("❌ Отсутствует разрешение локальной сети")
                            self.connectionStatus = .disconnected
                            self.error = HueAPIError.localNetworkPermissionDenied
                        }
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Ошибка при запросе разрешения локальной сети: \(error)")
                        self.connectionStatus = .disconnected
                        self.error = HueAPIError.localNetworkPermissionDenied
                    }
                }
            }
        } else {
            // Для iOS < 14 запускаем напрямую
            startDiscoveryProcess()
        }
    }
    
    /// Внутренний метод для запуска поиска после проверки разрешений
    private func startDiscoveryProcess() {
        // Создаем улучшенный discovery класс с проверкой совместимости
        if #available(iOS 12.0, *) {
            let discovery = HueBridgeDiscovery()
            discovery.discoverBridges { [weak self] bridges in
                self?.handleDiscoveryResults(bridges)
            }
        } else {
            // Fallback для старых версий iOS
            self.handleLegacyDiscovery()
        }
    }
    
    /// Обработка результатов поиска
    private func handleDiscoveryResults(_ bridges: [Bridge]) {
        DispatchQueue.main.async { [weak self] in
            print("📋 Discovery завершен с результатом: \(bridges.count) мостов")
            for bridge in bridges {
                print("  📡 Мост: \(bridge.id) at \(bridge.internalipaddress)")
            }
            
            self?.discoveredBridges = bridges
            
            if bridges.isEmpty {
                print("❌ Мосты не найдены")
                self?.connectionStatus = .disconnected
                #if os(iOS)
                self?.error = HueAPIError.localNetworkPermissionDenied
                #endif
            } else {
                print("✅ Найдено мостов: \(bridges.count)")
                self?.connectionStatus = .discovered
                self?.error = nil
            }
        }
    }
    
    /// Fallback discovery для старых версий iOS
    private func handleLegacyDiscovery() {
        print("📱 Используем legacy discovery для iOS < 12.0")
        // Здесь можно реализовать простой cloud + IP scan без Network framework
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = .disconnected
            self?.error = HueAPIError.bridgeNotFound
        }
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
                        self?.showSetup = false
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
    
//    /// Поиск мостов (обертка для OnboardingView)
//    func searchForBridges() {
//        discoverBridges()
//    }
    
    /// Создание пользователя на конкретном мосту
    /// - Parameters:
    ///   - bridge: Мост для подключения
    ///   - appName: Имя приложения
    ///   - deviceName: Имя устройства
    ///   - completion: Обработчик завершения
    func createUser(on bridge: Bridge, appName: String, deviceName: String, completion: @escaping (Bool) -> Void) {
        // Сначала подключаемся к мосту если еще не подключены
        if currentBridge?.id != bridge.id {
            connectToBridge(bridge)
        }
        
        // Создаем пользователя
        createUser(appName: appName, completion: completion)
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
    
    /// Настраивает наблюдение за состоянием приложения для автоматического обновления данных
        private func setupAppStateObservation() {
            #if canImport(UIKit)
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                .sink { [weak self] _ in
                    // ИСПРАВЛЕНИЕ: Обновляем только если есть подключение
                    if self?.connectionStatus == .connected {
                        print("🔄 Приложение стало активным - обновляем данные ламп")
                        self?.lightsViewModel.loadLights()
                    } else {
                        print("⚠️ Приложение стало активным - нет подключения, пропускаем обновление")
                    }
                }
                .store(in: &cancellables)
            #endif
        }
    
    // MARK: - Private Methods
        
        /// Загружает сохраненные настройки
        private func loadSavedSettings() {
            // Сначала пробуем загрузить из Keychain (новый метод)
            if let credentials = HueKeychainManager.shared.getLastBridgeCredentials() {
                loadSavedSettingsFromKeychain()
                return
            }
            
            // Fallback на старый метод с UserDefaults
            if let savedIP = UserDefaults.standard.string(forKey: "HueBridgeIP"),
               let savedKey = UserDefaults.standard.string(forKey: "HueApplicationKey") {
                
                applicationKey = savedKey
                recreateAPIClient(with: savedIP)
                
                // Загружаем client key для Entertainment API из Keychain
                if let bridgeId = UserDefaults.standard.string(forKey: "HueBridgeID"),
                   let clientKey = HueKeychainManager.shared.getClientKey(for: bridgeId) {
                    setupEntertainmentClient(clientKey: clientKey)
                }
                
                currentBridge = Bridge(
                    id: "",
                    internalipaddress: savedIP,
                    port: 443
                )
                
                connectionStatus = .connected
                startEventStream()
                // loadAllData() теперь вызывается в recreateAPIClient после установки ключа
            } else {
                // ИСПРАВЛЕНИЕ: При первом запуске НЕ пытаемся загружать данные
                showSetup = true
                connectionStatus = .disconnected
                print("🚀 Первый запуск - ждем настройки подключения")
            }
        }
    

    
    /// Пересоздает API клиент с новым IP
    /// ИСПРАВЛЕНИЕ: Добавлено логирование и правильное обновление ViewModels
    private func recreateAPIClient(with ip: String) {
        print("🔄 Пересоздаем API клиент с IP: \(ip)")
        
        // Создаем новый клиент с передачей DataPersistenceService
        apiClient = HueAPIClient(bridgeIP: ip, dataPersistenceService: dataPersistenceService)
        
        // ИСПРАВЛЕНИЕ: Обновляем ссылки в дочерних ViewModels и принудительно обновляем UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🔄 Обновляем дочерние ViewModels...")
            self.lightsViewModel = LightsViewModel(apiClient: self.apiClient)
            self.scenesViewModel = ScenesViewModel(apiClient: self.apiClient)
            self.groupsViewModel = GroupsViewModel(apiClient: self.apiClient)
            self.sensorsViewModel = SensorsViewModel(apiClient: self.apiClient)
            self.rulesViewModel = RulesViewModel(apiClient: self.apiClient)
            
            print("✅ ViewModels обновлены с новым API клиентом")
            
            // Устанавливаем application key если есть
            if let key = self.applicationKey {
                print("🔑 Устанавливаем application key в новый клиент")
                self.apiClient.setApplicationKey(key)
                
                // ИСПРАВЛЕНИЕ: Загружаем данные только после установки ключа
                print("🚀 Загружаем данные после установки application key...")
                self.loadAllData()
            } else {
                print("⚠️ Application key отсутствует - пропускаем загрузку данных")
            }
        }
    }
    

    /// Загружает все данные
        private func loadAllData() {
            // ИСПРАВЛЕНИЕ: Проверяем подключение перед загрузкой
            guard connectionStatus == .connected else {
                print("⚠️ Нет подключения - пропускаем загрузку данных")
                return
            }
            
            print("📦 Загружаем все данные с моста...")
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
    

    
    // MARK: - Memory Management

    deinit {
        print("♻️ AppViewModel деинициализация")
        eventStreamCancellable?.cancel()
        apiClient.disconnectEventStream()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        entertainmentClient?.stopSession()
        entertainmentClient = nil
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



/// Модель для данных QR-кода Hue Bridge
struct HueBridgeQRCode {
    /// Серийный номер моста
    let serialNumber: String
    
    /// ID моста (если доступен)
    let bridgeId: String?
    
    /// Инициализация из строки QR-кода
    init?(from qrString: String) {
        let cleaned = qrString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Парсим различные форматы QR-кодов
        if cleaned.hasPrefix("S#") {
            // Формат: S#12345678
            self.serialNumber = String(cleaned.dropFirst(2))
            self.bridgeId = nil
        } else if let url = URL(string: cleaned),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // URL формат: https://...?serial=S%2312345678&id=...
            var serial: String?
            var id: String?
            
            for queryItem in components.queryItems ?? [] {
                switch queryItem.name {
                case "serial":
                    serial = queryItem.value?.replacingOccurrences(of: "S#", with: "")
                case "id":
                    id = queryItem.value
                default:
                    break
                }
            }
            
            guard let serialNumber = serial else { return nil }
            self.serialNumber = serialNumber
            self.bridgeId = id
        } else {
            // Неизвестный формат
            return nil
        }
    }
}

/// Расширение для работы с N-UPnP (Network Universal Plug and Play)
extension AppViewModel {
    /// Поиск моста по серийному номеру через N-UPnP
   
      func discoverBridge(bySerial serial: String, completion: @escaping (Bridge?) -> Void) {
          // Сначала пробуем облачный поиск
          apiClient.discoverBridgesViaCloud()
              .receive(on: DispatchQueue.main)
              .sink(
                  receiveCompletion: { _ in },
                  receiveValue: { bridges in
                      // Ищем мост по частичному совпадению ID
                      let foundBridge = bridges.first { bridge in
                          // ID моста НЕ опциональный, поэтому используем напрямую
                          let bridgeId = bridge.id
                          return bridgeId.lowercased().contains(serial.lowercased()) ||
                                 serial.lowercased().contains(bridgeId.lowercased())
                      }
                      completion(foundBridge)
                  }
              )
              .store(in: &cancellables)
      }
    
    /// Валидация моста через запрос к description.xml
    func validateBridge(_ bridge: Bridge, completion: @escaping (Bool) -> Void) {
        print("🔍 Валидируем мост \(bridge.internalipaddress)...")
        
        // Создаем URL для description.xml
        guard let url = URL(string: "https://\(bridge.internalipaddress)/description.xml") else {
            print("❌ Невалидный URL для моста")
            completion(false)
            return
        }
        
        // Выполняем запрос
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Ошибка при валидации моста: \(error)")
                completion(false)
                return
            }
            
            guard let data = data,
                  let xmlString = String(data: data, encoding: .utf8) else {
                print("❌ Не удалось получить XML данные")
                completion(false)
                return
            }
            
            // Проверяем что это Philips Hue Bridge
            let isHueBridge = xmlString.contains("Philips hue") || 
                             xmlString.contains("Royal Philips Electronics") ||
                             xmlString.contains("modelName>Philips hue bridge")
            
            if isHueBridge {
                print("✅ Подтверждено: это Philips Hue Bridge")
            } else {
                print("❌ Это не Philips Hue Bridge")
            }
            
            completion(isHueBridge)
        }.resume()
    }
    
    /// Подключение к мосту с использованием Touch Link
    func connectWithTouchLink(bridge: Bridge, completion: @escaping (Bool) -> Void) {
        // Touch Link - альтернативный метод подключения
        // Работает только если устройство находится очень близко к мосту
        
        // В API v2 Touch Link не поддерживается напрямую
        // Используем стандартный метод с кнопкой Link
        connectToBridge(bridge)
        
        // Начинаем попытки создания пользователя
        var attempts = 0
        let maxAttempts = 10
        
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { timer in
            attempts += 1
            
            self.createUser(appName: "PhilipsHueV2") { success in
                if success {
                    timer.invalidate()
                    completion(true)
                } else if attempts >= maxAttempts {
                    timer.invalidate()
                    completion(false)
                }
            }
        }
    }
}


extension AppViewModel {
    
    /// Загружает сохраненные настройки из Keychain
    func loadSavedSettingsFromKeychain() {
        if let credentials = HueKeychainManager.shared.getLastBridgeCredentials() {
            // Устанавливаем ключи сначала
            applicationKey = credentials.applicationKey
            
            // Пересоздаем API клиент (теперь loadAllData будет вызван в recreateAPIClient)
            recreateAPIClient(with: credentials.bridgeIP)
            
            // Настраиваем Entertainment клиент если есть client key
            if let clientKey = credentials.clientKey {
                setupEntertainmentClient(clientKey: clientKey)
            }
            
            // Создаем объект моста
            currentBridge = Bridge(
                id: credentials.bridgeId,
                internalipaddress: credentials.bridgeIP,
                port: 443
            )
            
            connectionStatus = .connected
            startEventStream()
            // loadAllData() теперь вызывается в recreateAPIClient после установки ключа
        } else {
            showSetup = true
        }
    }
    
    /// Сохраняет учетные данные при успешном подключении
    func saveCredentials() {
        guard let bridge = currentBridge,
              let appKey = applicationKey else { return }
        
        let clientKey = HueKeychainManager.shared.getClientKey(for: bridge.id)
        
        let credentials = HueKeychainManager.BridgeCredentials(
            bridgeId: bridge.id,
            bridgeIP: bridge.internalipaddress,
            applicationKey: appKey,
            clientKey: clientKey
        )
        
        _ = HueKeychainManager.shared.saveBridgeCredentials(credentials)
    }
    
    /// Отключается от моста и удаляет сохраненные данные
    func disconnectAndClearData() {
        guard let bridge = currentBridge else { return }
        
        // Отключаемся
        disconnect()
        
        // Удаляем учетные данные из Keychain
        HueKeychainManager.shared.deleteCredentials(for: bridge.id)
    }
    
    /// Создает пользователя с улучшенной обработкой ошибок
    func createUserEnhanced(appName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
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
                        // Детальная обработка ошибок
                        if let hueError = error as? HueAPIError {
                            switch hueError {
                            case .linkButtonNotPressed:
                                completion(.failure(LinkButtonError.notPressed))
                            case .httpError(let statusCode):
                                if statusCode == 429 {
                                    completion(.failure(LinkButtonError.tooManyAttempts))
                                } else {
                                    completion(.failure(error))
                                }
                            default:
                                completion(.failure(error))
                            }
                        } else {
                            completion(.failure(error))
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    if let success = response.success,
                       let username = success.username {
                        self?.applicationKey = username
                        
                        // Сохраняем client key для Entertainment API
                        if let clientKey = success.clientkey {
                            self?.setupEntertainmentClient(clientKey: clientKey)
                        }
                        
                        self?.connectionStatus = .connected
                        self?.showSetup = false
                        self?.startEventStream()
                        self?.loadAllData()
                        
                        // Сохраняем учетные данные
                        self?.saveCredentials()
                        
                        completion(.success(true))
                    } else if let error = response.error {
                        // Проверяем код ошибки
                        switch error.type {
                        case 101:
                            completion(.failure(LinkButtonError.notPressed))
                        case 7:
                            completion(.failure(LinkButtonError.invalidRequest))
                        default:
                            completion(.failure(LinkButtonError.unknown(error.description ?? "Unknown error")))
                        }
                    } else {
                        completion(.failure(LinkButtonError.unknown("No response")))
                    }
                }
            )
            .store(in: &cancellables)
    }
}

extension AppViewModel {
    
    /// Создает пользователя с обработкой локальной сети
    func createUserWithRetry(appName: String, completion: @escaping (Bool) -> Void) {
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        
        // Проверяем что у нас есть подключение к мосту
        guard let bridge = currentBridge else {
            print("❌ Нет выбранного моста")
            completion(false)
            return
        }
        
        print("🔐 Попытка создания пользователя на мосту: \(bridge.internalipaddress)")
        
        apiClient.createUserWithLocalNetworkCheck(appName: appName, deviceName: deviceName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        print("❌ AppViewModel: Ошибка создания пользователя: \(error)")
                        
                        // Специальная обработка ошибки локальной сети
                        if let nsError = error as NSError?,
                           nsError.code == -1009 {
                            print("🚫 AppViewModel: Нет доступа к локальной сети!")
                            self.error = HueAPIError.localNetworkPermissionDenied
                        } else if let hueError = error as? HueAPIError,
                                  case .linkButtonNotPressed = hueError {
                            print("⏳ AppViewModel: Кнопка Link еще не нажата")
                            self.error = HueAPIError.linkButtonNotPressed
                            // Это нормально - продолжаем попытки
                        } else {
                            print("⚠️ AppViewModel: Неизвестная ошибка: \(error)")
                            self.error = error as? HueAPIError ?? HueAPIError.invalidResponse
                        }
                        
                        completion(false)
                    }
                },
                receiveValue: { [weak self] response in
                    if let success = response.success,
                       let username = success.username {
                        print("✅ Пользователь создан! Username: \(username)")
                        
                        self?.applicationKey = username
                        
                        // Сохраняем client key для Entertainment API в Keychain
                        if let clientKey = success.clientkey {
                            print("🔑 Client key: \(clientKey)")
                            // Сохраняем в Keychain вместо UserDefaults для безопасности
                            if let bridgeId = self?.currentBridge?.id {
                                _ = HueKeychainManager.shared.saveClientKey(clientKey, for: bridgeId)
                            }
                            self?.setupEntertainmentClient(clientKey: clientKey)
                        }
                        
                        self?.connectionStatus = .connected
                        self?.showSetup = false
                        self?.startEventStream()
                        self?.loadAllData()
                        self?.saveCredentials()
                        
                        completion(true)
                    } else {
                        print("❌ Неожиданный ответ от API")
                        completion(false)
                    }
                }
            )
            .store(in: &cancellables)
    }
}

/// Ошибки при нажатии кнопки Link
enum LinkButtonError: LocalizedError {
    case notPressed
    case tooManyAttempts
    case timeout
    case invalidRequest
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notPressed:
            return "Нажмите кнопку Link на Hue Bridge"
        case .tooManyAttempts:
            return "Слишком много попыток. Подождите минуту и попробуйте снова"
        case .timeout:
            return "Время ожидания истекло. Попробуйте снова"
        case .invalidRequest:
            return "Неверный запрос. Проверьте подключение к мосту"
        case .unknown(let message):
            return "Ошибка: \(message)"
        }
    }
}
