//
//  BridgeRepositoryImpl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine
import Network

/// Конкретная реализация BridgeRepository 
/// Использует существующие компоненты для работы с Philips Hue Bridge
class BridgeRepositoryImpl: BridgeRepository {
    
    // MARK: - Dependencies
    
    private let hueBridgeDiscovery: HueBridgeDiscovery
    private let smartBridgeDiscovery = SmartBridgeDiscovery()
    private let hueAPIClient: HueAPIClient
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let savedBridgeKey = "saved_bridge"
    private let allBridgesKey = "all_saved_bridges"
    
    // MARK: - Initialization
    
    init(hueAPIClient: HueAPIClient) {
        self.hueAPIClient = hueAPIClient
        
        // Проверяем доступность HueBridgeDiscovery
        if #available(iOS 12.0, *) {
            self.hueBridgeDiscovery = HueBridgeDiscovery()
        } else {
            // Для более старых версий создаем заглушку
            self.hueBridgeDiscovery = HueBridgeDiscovery()
        }
    }
    
    // MARK: - Bridge Discovery
    
    func discoverBridges() -> AnyPublisher<[BridgeEntity], Error> {
        return Future<[BridgeEntity], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(BridgeRepositoryError.bridgeNotFound))
                return
            }
            
            print("🔍 [BridgeRepository] Запускаем поиск мостов...")
            
            // Используем существующий HueBridgeDiscovery
            self.hueBridgeDiscovery.discoverBridges { bridges in
                let bridgeEntities = bridges.map { bridge in
                    BridgeEntity(from: bridge)
                }
                
                print("✅ [BridgeRepository] Найдено мостов: \(bridgeEntities.count)")
                promise(.success(bridgeEntities))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func discoverBridgesViaMDNS() -> AnyPublisher<[BridgeEntity], Error> {
        return Future<[BridgeEntity], Error> { promise in
            // Используем mDNS discovery из SmartBridgeDiscovery
            let devices = SmartBridgeDiscovery.getLocalNetworkDevices()
            
            // Конвертируем найденные IP в Bridge entities для дальнейшей проверки
            let bridgeEntities = devices.enumerated().map { index, ip in
                BridgeEntity(
                    id: UUID().uuidString,
                    name: "Philips Hue Bridge",
                    ipAddress: ip,
                    isConnected: false
                )
            }
            
            print("✅ [BridgeRepository] mDNS поиск: найдено потенциальных устройств \(bridgeEntities.count)")
            promise(.success(bridgeEntities))
        }
        .eraseToAnyPublisher()
    }
    
    func discoverBridgesViaPhilips() -> AnyPublisher<[BridgeEntity], Error> {
        return Future<[BridgeEntity], Error> { [weak self] promise in
            // Используем cloud discovery из HueBridgeDiscovery
            // Делаем запрос к официальному Philips сервису
            self?.discoverBridgesViaCloudService { bridges in
                let bridgeEntities = bridges.map { bridge in
                    BridgeEntity(from: bridge)
                }
                
                print("✅ [BridgeRepository] Philips Cloud поиск: найдено мостов \(bridgeEntities.count)")
                promise(.success(bridgeEntities))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Bridge Connection
    
    func connectToBridge(_ bridge: BridgeEntity, forcePairing: Bool = false) -> AnyPublisher<BridgeEntity, Error> {
        return Future<BridgeEntity, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(BridgeRepositoryError.bridgeNotFound))
                return
            }
            
            print("🔗 [BridgeRepository] Подключаемся к мосту: \(bridge.name) (\(bridge.ipAddress))")
            
            // Проверяем подключение
            self.checkBridgeConnection(bridge)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { isConnected in
                        if isConnected {
                            // Если уже подключены и не нужно принудительное переподключение
                            if !forcePairing && bridge.applicationKey != nil {
                                promise(.success(bridge))
                                return
                            }
                        }
                        
                        // Нужна аутентификация
                        promise(.success(bridge)) // Возвращаем мост для дальнейшей аутентификации
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    func authenticateWithBridge(_ bridge: BridgeEntity, appName: String, deviceName: String) -> AnyPublisher<BridgeEntity, Error> {
        return Future<BridgeEntity, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(BridgeRepositoryError.bridgeNotFound))
                return
            }
            
            print("🔐 [BridgeRepository] Аутентификация с мостом: \(bridge.name)")
            
            // Используем существующий HueAPIClient для аутентификации
            self.hueAPIClient.createUser(appName: appName, deviceName: deviceName)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ [BridgeRepository] Ошибка аутентификации: \(error)")
                            promise(.failure(BridgeRepositoryError.authenticationFailed))
                        }
                    },
                    receiveValue: { authResponse in
                        // Создаем обновленный bridge с application key
                        let authenticatedBridge = BridgeEntity(
                            id: bridge.id,
                            name: bridge.name,
                            ipAddress: bridge.ipAddress,
                            modelId: bridge.modelId,
                            swVersion: bridge.swVersion,
                            applicationKey: authResponse.success?.username,
                            isConnected: true,
                            lastSeen: Date()
                        )
                        
                        print("✅ [BridgeRepository] Аутентификация успешна")
                        promise(.success(authenticatedBridge))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    func checkBridgeConnection(_ bridge: BridgeEntity) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(BridgeRepositoryError.bridgeNotFound))
                return
            }
            
            // Проверяем доступность моста через простой HTTP запрос
            guard let url = URL(string: "https://\(bridge.ipAddress)/api/config") else {
                promise(.failure(BridgeRepositoryError.invalidBridgeData))
                return
            }
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    promise(.failure(BridgeRepositoryError.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    promise(.failure(BridgeRepositoryError.bridgeUnavailable))
                    return
                }
                
                promise(.success(true))
            }
            
            task.resume()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Bridge Info
    
    func getBridgeInfo(_ bridge: BridgeEntity) -> AnyPublisher<BridgeEntity, Error> {
        return getBridgeConfig(bridge)
            .map { config in
                // Обновляем bridge entity с информацией из конфигурации
                BridgeEntity(
                    id: bridge.id,
                    name: config.name ?? bridge.name,
                    ipAddress: bridge.ipAddress,
                    modelId: config.modelid,
                    swVersion: config.swversion,
                    applicationKey: bridge.applicationKey,
                    isConnected: bridge.isConnected,
                    lastSeen: Date()
                )
            }
            .eraseToAnyPublisher()
    }
    
    func getBridgeConfig(_ bridge: BridgeEntity) -> AnyPublisher<BridgeConfig, Error> {
        return Future<BridgeConfig, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(BridgeRepositoryError.bridgeNotFound))
                return
            }
            
            self.hueAPIClient.getBridgeConfig()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            promise(.failure(BridgeRepositoryError.networkError(error)))
                        }
                    },
                    receiveValue: { config in
                        promise(.success(config))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    func getBridgeCapabilities(_ bridge: BridgeEntity) -> AnyPublisher<BridgeCapabilities, Error> {
        return Future<BridgeCapabilities, Error> { promise in
            // Заглушка - возвращаем базовые возможности
            let capabilities = BridgeCapabilities(
                resources: ResourceLimits(
                    lights: 50,
                    sensors: 62,
                    groups: 64,
                    scenes: 200,
                    rules: 250,
                    schedules: 100,
                    resourcelinks: 64,
                    whitelists: 16
                ),
                streaming: StreamingLimits(total: 10, entertainment: 1),
                timezones: ["UTC", "Europe/Moscow"]
            )
            
            promise(.success(capabilities))
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Bridge Storage
    
    func saveBridge(_ bridge: BridgeEntity) -> AnyPublisher<BridgeEntity, Error> {
        return Future<BridgeEntity, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(BridgeRepositoryError.bridgeNotFound))
                return
            }
            
            do {
                let data = try JSONEncoder().encode(bridge)
                self.userDefaults.set(data, forKey: self.savedBridgeKey)
                
                // Также сохраняем в общий список мостов
                var allBridges = self.loadAllSavedBridges()
                
                // Удаляем существующий мост с таким же ID, если есть
                allBridges.removeAll { $0.id == bridge.id }
                
                // Добавляем обновленный мост
                allBridges.append(bridge)
                
                let allBridgesData = try JSONEncoder().encode(allBridges)
                self.userDefaults.set(allBridgesData, forKey: self.allBridgesKey)
                
                print("✅ [BridgeRepository] Мост сохранен: \(bridge.name)")
                promise(.success(bridge))
                
            } catch {
                promise(.failure(BridgeRepositoryError.invalidBridgeData))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getSavedBridge() -> AnyPublisher<BridgeEntity?, Never> {
        return Future<BridgeEntity?, Never> { [weak self] promise in
            guard let self = self,
                  let data = self.userDefaults.data(forKey: self.savedBridgeKey) else {
                promise(.success(nil))
                return
            }
            
            do {
                let bridge = try JSONDecoder().decode(BridgeEntity.self, from: data)
                promise(.success(bridge))
            } catch {
                print("❌ [BridgeRepository] Ошибка загрузки сохраненного моста: \(error)")
                promise(.success(nil))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func removeSavedBridge() -> AnyPublisher<Void, Never> {
        return Future<Void, Never> { [weak self] promise in
            self?.userDefaults.removeObject(forKey: self?.savedBridgeKey ?? "")
            print("✅ [BridgeRepository] Сохраненный мост удален")
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    func getAllSavedBridges() -> AnyPublisher<[BridgeEntity], Never> {
        return Future<[BridgeEntity], Never> { [weak self] promise in
            let bridges = self?.loadAllSavedBridges() ?? []
            promise(.success(bridges))
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func loadAllSavedBridges() -> [BridgeEntity] {
        guard let data = userDefaults.data(forKey: allBridgesKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([BridgeEntity].self, from: data)
        } catch {
            print("❌ [BridgeRepository] Ошибка загрузки всех сохраненных мостов: \(error)")
            return []
        }
    }
    
    private func discoverBridgesViaCloudService(completion: @escaping ([Bridge]) -> Void) {
        // Запрос к официальному Philips Discovery Service
        guard let url = URL(string: "https://discovery.meethue.com/") else {
            completion([])
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Cloud discovery error: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                completion([])
                return
            }
            
            do {
                let bridges = try JSONDecoder().decode([Bridge].self, from: data)
                print("✅ Cloud discovery: найдено мостов \(bridges.count)")
                completion(bridges)
            } catch {
                print("❌ Cloud discovery parsing error: \(error)")
                completion([])
            }
        }
        
        task.resume()
    }
}
