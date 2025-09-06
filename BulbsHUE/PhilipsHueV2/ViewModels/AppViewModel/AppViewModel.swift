import Foundation
import Combine
import Observation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Главный ViewModel приложения
/// Управляет состоянием подключения и координирует другие ViewModels
/// ✅ ОБНОВЛЕНО: Мигрировано на @Observable
@MainActor
@Observable
class AppViewModel {
    
    // MARK: - Observable Properties
    
    /// ✅ ОБНОВЛЕНО: Убрали @Published - @Observable отслеживает автоматически
    var connectionStatus: ConnectionStatus = .disconnected
    var discoveredBridges: [Bridge] = []
    var currentBridge: Bridge?
    var applicationKey: String? {
        didSet {
            if let key = applicationKey {
                UserDefaults.standard.set(key, forKey: "HueApplicationKey")
                apiClient.setApplicationKey(key)
            }
        }
    }
    var showSetup: Bool = false
    var bridgeCapabilities: BridgeCapabilities?
    // MARK: - Deprecated Properties
    // Удален PerformanceMetrics для @Observable
    // var performanceMetrics = PerformanceMetrics()
    var error: Error?
    
    // MARK: - Child ViewModels
    
    var lightsViewModel: LightsViewModel
    var scenesViewModel: ScenesViewModel
    var groupsViewModel: GroupsViewModel
    var sensorsViewModel: SensorsViewModel
    var rulesViewModel: RulesViewModel
    
    // MARK: - Internal Properties (для доступа из расширений)
    
    internal var apiClient: HueAPIClient
    internal var cancellables = Set<AnyCancellable>()
    internal var eventStreamCancellable: AnyCancellable?
    internal var entertainmentClient: HueEntertainmentClient?
    internal weak var dataPersistenceService: DataPersistenceService?
    
    // MARK: - Reconnection Properties
    
    internal var connectionCheckTimer: Timer?
    internal var networkMonitor: AnyObject? // NWPathMonitor для iOS 12+
    
    // MARK: - Public Properties
    
    var dataService: DataPersistenceService? {
        return dataPersistenceService
    }
    
    // MARK: - Initialization
    
    init(dataPersistenceService: DataPersistenceService? = nil) {
        self.dataPersistenceService = dataPersistenceService
        let apiClientInstance = HueAPIClient(bridgeIP: "", dataPersistenceService: dataPersistenceService)
        self.apiClient = apiClientInstance
        
        self.lightsViewModel = LightsViewModel(apiClient: apiClientInstance)
        self.scenesViewModel = ScenesViewModel(apiClient: apiClientInstance)
        self.groupsViewModel = GroupsViewModel(apiClient: apiClientInstance)
        self.sensorsViewModel = SensorsViewModel(apiClient: apiClientInstance)
        self.rulesViewModel = RulesViewModel(apiClient: apiClientInstance)
        
        setupPerformanceMonitoring()
        setupAppStateObservation()
        loadSavedSettings()
    }
    
    // MARK: - Public Methods
    
    func hasValidConnection() -> Bool {
        return apiClient.hasValidConnection()
    }
    
    func refreshAll() {
        loadAllData()
    }
    
    func disconnect() {
        connectionStatus = .disconnected
        currentBridge = nil
        applicationKey = nil
        eventStreamCancellable?.cancel()
        
        // Останавливаем мониторинг подключения
        stopConnectionMonitoring()
        
        UserDefaults.standard.removeObject(forKey: "HueBridgeIP")
        UserDefaults.standard.removeObject(forKey: "HueApplicationKey")
    }
    
    // MARK: - Internal Methods (доступны в расширениях)
    
    internal func recreateAPIClient(with ip: String) {
        print("🔄 Пересоздаем API клиент с IP: \(ip)")
        
        // Останавливаем event streams перед пересозданием
        lightsViewModel.stopEventStream()
        
        // Отменяем все активные подписки перед пересозданием
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        eventStreamCancellable?.cancel()
        eventStreamCancellable = nil
        
        // Создаем новый API клиент
        apiClient = HueAPIClient(bridgeIP: ip, dataPersistenceService: dataPersistenceService)
        
        print("🔄 Обновляем дочерние ViewModels...")
        
        // ИСПРАВЛЕНИЕ: Принудительно обнуляем старые ViewModels для разрыва retain cycles
        print("🗑️ Очищаем старые ViewModels...")
        
        // Создаем новые ViewModels синхронно на главном потоке
        self.lightsViewModel = LightsViewModel(apiClient: self.apiClient)
        self.scenesViewModel = ScenesViewModel(apiClient: self.apiClient)
        self.groupsViewModel = GroupsViewModel(apiClient: self.apiClient)
        self.sensorsViewModel = SensorsViewModel(apiClient: self.apiClient)
        self.rulesViewModel = RulesViewModel(apiClient: self.apiClient)
        
        print("✅ ViewModels обновлены с новым API клиентом")
        
        if let key = self.applicationKey {
            print("🔑 Устанавливаем application key в новый клиент")
            self.apiClient.setApplicationKey(key)
            print("🚀 Загружаем данные после установки application key...")
            self.loadAllData()
        } else {
            print("⚠️ Application key отсутствует - пропускаем загрузку данных")
        }
    }
    
    internal func loadAllData() {
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
    
    internal func startEventStream() {
        eventStreamCancellable?.cancel()
        
        lightsViewModel.startEventStream()
        
        eventStreamCancellable = apiClient.connectToEventStream()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] event in
                    self?.handleEvent(event)
                }
            )
    }
    
    internal func handleEvent(_ event: HueEvent) {
        // performanceMetrics.eventsReceived += 1
    }
    
    internal func setupEntertainmentClient(clientKey: String) {
        guard let bridge = currentBridge else { return }
        entertainmentClient = HueEntertainmentClient(
            bridgeIP: bridge.internalipaddress,
            applicationKey: applicationKey ?? "",
            clientKey: clientKey
        )
    }
    
    internal func saveClientKey(_ clientKey: String) {
        guard let bridgeId = currentBridge?.id else { return }
        _ = HueKeychainManager.shared.saveClientKey(clientKey, for: bridgeId)
        setupEntertainmentClient(clientKey: clientKey)
    }
    
    // MARK: - Private Methods
    
    private func loadSavedSettings() {
        // Приоритет 1: Проверяем Keychain (более полная информация)
        if let credentials = HueKeychainManager.shared.getLastBridgeCredentials() {
            print("📱 Загружаем сохраненные настройки из Keychain...")
            
            applicationKey = credentials.applicationKey
            recreateAPIClient(with: credentials.bridgeIP)
            
            if let clientKey = credentials.clientKey {
                setupEntertainmentClient(clientKey: clientKey)
            }
            
            currentBridge = Bridge(
                id: credentials.bridgeId,
                internalipaddress: credentials.bridgeIP,
                port: 443
            )
            
            // Проверяем доступность моста перед установкой статуса
            connectionStatus = .connecting
            showSetup = false
            
            // Проверяем, доступен ли мост
            Task {
                await verifyBridgeConnection(credentials.bridgeIP) { [weak self] isAvailable in
                    if isAvailable {
                        self?.connectionStatus = .connected
                        self?.startEventStream()
                        self?.loadAllData()
                        
                        // Запускаем мониторинг подключения после успешного подключения
                        self?.startConnectionMonitoring()
                    } else {
                        print("⚠️ Сохраненный мост недоступен, ищем его в сети...")
                        self?.rediscoverSavedBridge()
                    }
                }
            }
            
            return
        }
        
        // Приоритет 2: Проверяем UserDefaults (legacy)
        if let savedIP = UserDefaults.standard.string(forKey: "HueBridgeIP"),
           let savedKey = UserDefaults.standard.string(forKey: "HueApplicationKey") {
            
            print("📱 Загружаем сохраненные настройки из UserDefaults...")
            
            applicationKey = savedKey
            recreateAPIClient(with: savedIP)
            
            // Получаем Bridge ID если сохранен
            let bridgeId = UserDefaults.standard.string(forKey: "HueBridgeID") ?? ""
            
            if !bridgeId.isEmpty,
               let clientKey = HueKeychainManager.shared.getClientKey(for: bridgeId) {
                setupEntertainmentClient(clientKey: clientKey)
            }
            
            currentBridge = Bridge(
                id: bridgeId,
                internalipaddress: savedIP,
                port: 443
            )
            
            // Проверяем доступность моста
            connectionStatus = .connecting
            showSetup = false
            
            Task {
                await verifyBridgeConnection(savedIP) { [weak self] isAvailable in
                    if isAvailable {
                        // Получаем актуальный Bridge ID с моста
                        self?.updateBridgeInfo {
                            self?.connectionStatus = .connected
                            self?.startEventStream()
                            self?.loadAllData()
                            
                            // Запускаем мониторинг подключения
                            self?.startConnectionMonitoring()
                            
                            // Мигрируем данные в Keychain для будущего использования
                            self?.saveCredentials()
                        }
                    } else {
                        print("⚠️ Сохраненный мост недоступен по адресу \(savedIP)")
                        
                        // Если есть Bridge ID, пробуем найти мост в сети
                        if !bridgeId.isEmpty {
                            self?.rediscoverSavedBridge()
                        } else {
                            // Нет Bridge ID - показываем экран настройки
                            self?.connectionStatus = .disconnected
                            self?.showSetup = true
                        }
                    }
                }
            }
            
            return
        }
        
        // Нет сохраненных настроек - первый запуск
        showSetup = true
        connectionStatus = .disconnected
        print("🚀 Первый запуск - ждем настройки подключения")
    }
    
    // MARK: - Helper Methods
    
    /// Проверяет доступность моста по IP адресу
    private func verifyBridgeConnection(_ ip: String, completion: @escaping (Bool) -> Void) async {
        guard let url = URL(string: "https://\(ip)/api/\(applicationKey ?? "0")/config") else {
            await MainActor.run {
                completion(false)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        // Используем URLSession с делегатом для самоподписанных сертификатов
        let delegate = HueURLSessionDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                
                // Пробуем распарсить конфигурацию
                if let config = try? JSONDecoder().decode(BridgeConfig.self, from: data) {
                    await MainActor.run {
                        // Обновляем информацию о мосте если нужно
                        if let bridgeId = config.bridgeid, self.currentBridge?.id.isEmpty == true {
                            self.currentBridge?.id = bridgeId
                        }
                        if let name = config.name {
                            self.currentBridge?.name = name
                        }
                        completion(true)
                    }
                } else {
                    await MainActor.run {
                        completion(true) // Мост доступен, даже если не удалось распарсить
                    }
                }
            } else {
                await MainActor.run {
                    completion(false)
                }
            }
        } catch {
            print("❌ Ошибка проверки подключения: \(error)")
            await MainActor.run {
                completion(false)
            }
        }
    }
    
    /// Обновляет информацию о мосте с сервера
    private func updateBridgeInfo(completion: @escaping () -> Void) {
        apiClient.getBridgeConfig()
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { _ in
                    completion()
                },
                receiveValue: { [weak self] config in
                    if let bridgeId = config.bridgeid {
                        self?.currentBridge?.id = bridgeId
                        UserDefaults.standard.set(bridgeId, forKey: "HueBridgeID")
                    }
                    if let name = config.name {
                        self?.currentBridge?.name = name
                    }
                    completion()
                }
            )
            .store(in: &cancellables)
    }
    
    /// Переоткрывает сохраненный мост в сети
    private func rediscoverSavedBridge() {
        let savedBridgeId = currentBridge?.id ?? 
                           UserDefaults.standard.string(forKey: "HueBridgeID") ?? 
                           UserDefaults.standard.string(forKey: "lastUsedBridgeId") ?? ""
        
        if !savedBridgeId.isEmpty {
            print("🔍 Ищем мост с ID: \(savedBridgeId)")
            
            connectionStatus = .searching
            
            // Используем метод из расширения Reconnection
            searchForSpecificBridge(bridgeId: savedBridgeId) { [weak self] foundBridge in
                if let bridge = foundBridge {
                    print("✅ Мост найден по новому адресу: \(bridge.internalipaddress)")
                    
                    // Обновляем данные
                    self?.currentBridge = bridge
                    UserDefaults.standard.set(bridge.internalipaddress, forKey: "HueBridgeIP")
                    
                    // Переподключаемся
                    self?.recreateAPIClient(with: bridge.internalipaddress)
                    self?.connectionStatus = .connected
                    self?.showSetup = false
                    self?.startEventStream()
                    self?.loadAllData()
                    
                    // Сохраняем обновленные credentials
                    self?.saveCredentials()
                    
                    // Запускаем мониторинг подключения
                    self?.startConnectionMonitoring()
                    
                } else {
                    print("❌ Не удалось найти сохраненный мост в сети")
                    self?.connectionStatus = .disconnected
                    self?.showSetup = true
                }
            }
        } else {
            print("❌ Нет сохраненного Bridge ID для поиска")
            connectionStatus = .disconnected
            showSetup = true
        }
    }
    
    private func setupAppStateObservation() {
        #if canImport(UIKit)
        // При возврате из фона - делаем мягкое обновление состояния
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                if self?.connectionStatus == .connected {
                    print("🔄 Приложение стало активным - обновляем состояние ламп")
                    // ИСПРАВЛЕНИЕ: используем refreshLightsWithStatus вместо loadLights
                    // для сохранения пользовательского состояния при обновлении
                    Task { @MainActor in
                        await self?.lightsViewModel.refreshLightsWithStatus()
                    }
                } else {
                    print("⚠️ Приложение стало активным - нет подключения, пропускаем обновление")
                }
            }
            .store(in: &cancellables)
        
        // При уходе в фон - сохраняем текущее состояние
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                print("💾 Приложение ушло в фон - состояние ламп сохранено автоматически")
                // DataPersistenceService автоматически сохранит изменения через SwiftData
            }
            .store(in: &cancellables)
        #endif
    }
    
    private func setupPerformanceMonitoring() {
        apiClient.errorPublisher
            .sink { [weak self] error in
                switch error {
                case .rateLimitExceeded:
                    // self?.performanceMetrics.rateLimitHits += 1
                    print("⚠️ Rate limit exceeded")
                case .bufferFull:
                    // self?.performanceMetrics.bufferOverflows += 1
                    print("⚠️ Buffer full")
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
     func checkResourceLimits(_ capabilities: BridgeCapabilities) {
        guard let limits = capabilities.resources else { return }
        
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
    
    /// Ищет конкретный мост по ID
    func searchForSpecificBridge(bridgeId: String, completion: @escaping (Bridge?) -> Void) {
        print("🔍 Поиск моста с ID: \(bridgeId)")
        
        // Используем метод из расширения Discovery
        if #available(iOS 12.0, *) {
            let discovery = HueBridgeDiscovery()
            discovery.discoverBridges { bridges in
                let foundBridge = bridges.first { $0.matches(bridgeId: bridgeId) }
                DispatchQueue.main.async {
                    completion(foundBridge)
                }
            }
        } else {
            // Для старых версий iOS используем облачный поиск
            apiClient.discoverBridgesViaCloud()
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { bridges in
                        let foundBridge = bridges.first { $0.matches(bridgeId: bridgeId) }
                        completion(foundBridge)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Deinit
    
    nonisolated deinit {
        print("♻️ AppViewModel деинициализация")
        
        // Cancellables и другие ресурсы освобождаются автоматически при деинициализации
        // Избегаем обращения к @MainActor свойствам в deinit для предотвращения retain cycles
    }
}

// MARK: - URLSession Delegate

private class HueURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, 
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ AppViewModel.swift
 
 Описание:
 Главный ViewModel приложения, управляющий состоянием подключения к Hue Bridge
 и координирующий работу дочерних ViewModels.
 
 Основные компоненты:
 - Управление состоянием подключения
 - Координация дочерних ViewModels (lights, scenes, groups, sensors, rules)
 - Управление API клиентом
 - Мониторинг производительности
 - Управление потоком событий
 
 Использование:
 let appViewModel = AppViewModel(dataPersistenceService: dataService)
 appViewModel.searchForBridges()
 appViewModel.connectToBridge(bridge)
 
 Зависимости:
 - HueAPIClient для взаимодействия с API
 - DataPersistenceService для хранения данных
 - Дочерние ViewModels для управления ресурсами
 
 Связанные файлы:
 - AppViewModel+Discovery.swift - поиск мостов
 - AppViewModel+Connection.swift - подключение к мосту
 - AppViewModel+LinkButton.swift - авторизация через Link Button
 - AppViewModel+Keychain.swift - работа с Keychain
 - AppViewModel+QRCode.swift - работа с QR кодами
 */
