import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Главный ViewModel приложения
/// Управляет состоянием подключения и координирует другие ViewModels
@MainActor
class AppViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var discoveredBridges: [Bridge] = []
    @Published var currentBridge: Bridge?
    @Published var applicationKey: String? {
        didSet {
            if let key = applicationKey {
                UserDefaults.standard.set(key, forKey: "HueApplicationKey")
                apiClient.setApplicationKey(key)
            }
        }
    }
    @Published var showSetup: Bool = false
    @Published var bridgeCapabilities: BridgeCapabilities?
    @Published var performanceMetrics = PerformanceMetrics()
    @Published var error: Error?
    
    // MARK: - Child ViewModels
    
    @Published var lightsViewModel: LightsViewModel
    @Published var scenesViewModel: ScenesViewModel
    @Published var groupsViewModel: GroupsViewModel
    @Published var sensorsViewModel: SensorsViewModel
    @Published var rulesViewModel: RulesViewModel
    
    // MARK: - Internal Properties (для доступа из расширений)
    
    internal var apiClient: HueAPIClient
    internal var cancellables = Set<AnyCancellable>()
    internal var eventStreamCancellable: AnyCancellable?
    internal var entertainmentClient: HueEntertainmentClient?
    internal weak var dataPersistenceService: DataPersistenceService?
    
    // MARK: - Public Properties
    
    var dataService: DataPersistenceService? {
        return dataPersistenceService
    }
    
    // MARK: - Initialization
    
    init(dataPersistenceService: DataPersistenceService? = nil) {
        self.dataPersistenceService = dataPersistenceService
        self.apiClient = HueAPIClient(bridgeIP: "", dataPersistenceService: dataPersistenceService)
        
        self.lightsViewModel = LightsViewModel(apiClient: apiClient)
        self.scenesViewModel = ScenesViewModel(apiClient: apiClient)
        self.groupsViewModel = GroupsViewModel(apiClient: apiClient)
        self.sensorsViewModel = SensorsViewModel(apiClient: apiClient)
        self.rulesViewModel = RulesViewModel(apiClient: apiClient)
        
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
        performanceMetrics.eventsReceived += 1
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
        if let credentials = HueKeychainManager.shared.getLastBridgeCredentials() {
            loadSavedSettingsFromKeychain()
            return
        }
        
        if let savedIP = UserDefaults.standard.string(forKey: "HueBridgeIP"),
           let savedKey = UserDefaults.standard.string(forKey: "HueApplicationKey") {
            
            applicationKey = savedKey
            recreateAPIClient(with: savedIP)
            
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
        } else {
            showSetup = true
            connectionStatus = .disconnected
            print("🚀 Первый запуск - ждем настройки подключения")
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
                    self?.performanceMetrics.rateLimitHits += 1
                case .bufferFull:
                    self?.performanceMetrics.bufferOverflows += 1
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
    
    // MARK: - Deinit
    
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
