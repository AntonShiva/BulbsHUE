//
//  AppViewModel+Reconnection.swift
//  BulbsHUE
//
//  Расширение для автоматического переподключения к мосту после его перезапуска
//

import Foundation
import Combine
import Network

extension AppViewModel {
    
    // MARK: - Reconnection Properties
    
    private struct ReconnectionConfig {
        static let maxRetryAttempts = 5
        static let initialRetryDelay: TimeInterval = 2.0
        static let maxRetryDelay: TimeInterval = 30.0
        static let connectionCheckInterval: TimeInterval = 10.0
    }
    
    // MARK: - Public Reconnection Methods
    
    /// Запускает мониторинг состояния подключения
    func startConnectionMonitoring() {
        guard connectionStatus == .connected else {
            print("⚠️ Пропускаем запуск мониторинга - соединение не установлено")
            return
        }
        
        print("🔄 Запуск мониторинга подключения...")
        
        // Останавливаем предыдущий мониторинг если есть
        stopConnectionMonitoring()
        
        // Периодическая проверка соединения
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: ReconnectionConfig.connectionCheckInterval, repeats: true) { [weak self] _ in
            self?.checkConnectionHealth()
        }
        
        // Мониторинг сетевого состояния
        if #available(iOS 12.0, *) {
            startNetworkPathMonitoring()
        }
    }
    
    /// Останавливает мониторинг состояния подключения
    func stopConnectionMonitoring() {
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = nil
        
        if #available(iOS 12.0, *) {
            if let monitor = networkMonitor as? NWPathMonitor {
                monitor.cancel()
            }
        }
        networkMonitor = nil
    }
    
    /// Проверяет состояние текущего подключения
    func checkConnectionHealth() {
        guard connectionStatus == .connected,
              let bridge = currentBridge else {
            return
        }
        
        // Проверяем доступность моста
        apiClient.getBridgeConfig()
            .timeout(.seconds(5), scheduler: RunLoop.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        print("⚠️ Мост недоступен, начинаем переподключение...")
                        self?.handleConnectionLost()
                    }
                },
                receiveValue: { [weak self] config in
                    // Мост доступен, обновляем информацию если нужно
                    if let bridgeId = config.bridgeid, 
                       self?.currentBridge?.id.isEmpty == true {
                        self?.currentBridge?.id = bridgeId
                        self?.saveCredentials()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обрабатывает потерю соединения
    private func handleConnectionLost() {
        connectionStatus = .reconnecting
        eventStreamCancellable?.cancel()
        
        // Останавливаем event streams
        lightsViewModel.stopEventStream()
        
        // Начинаем процесс переподключения
        attemptReconnection()
    }
    
    /// Пытается переподключиться к мосту
    func attemptReconnection(attemptNumber: Int = 1) {
        guard attemptNumber <= ReconnectionConfig.maxRetryAttempts else {
            print("❌ Превышено максимальное количество попыток переподключения")
            connectionStatus = .disconnected
            // Запускаем поиск нового моста
            rediscoverBridge()
            return
        }
        
        print("🔄 Попытка переподключения #\(attemptNumber)...")
        
        // Сначала пробуем сохраненный IP
        if let savedIP = currentBridge?.internalipaddress {
            tryConnectToIP(savedIP) { [weak self] success in
                if success {
                    print("✅ Успешно переподключились к мосту")
                    self?.onSuccessfulReconnection()
                } else {
                    // Увеличиваем задержку экспоненциально
                    let delay = min(
                        ReconnectionConfig.initialRetryDelay * pow(2, Double(attemptNumber - 1)),
                        ReconnectionConfig.maxRetryDelay
                    )
                    
                    print("⏱ Следующая попытка через \(delay) секунд...")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self?.attemptReconnection(attemptNumber: attemptNumber + 1)
                    }
                }
            }
        } else {
            // Если нет сохраненного IP, ищем мост заново
            rediscoverBridge()
        }
    }
    
    /// Пробует подключиться к конкретному IP
    private func tryConnectToIP(_ ip: String, completion: @escaping (Bool) -> Void) {
        // Проверяем доступность моста по IP
        guard let url = URL(string: "https://\(ip)/api/\(applicationKey ?? "0")/config") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        // Создаем сессию с делегатом для обработки самоподписанных сертификатов
        let session = URLSession(configuration: .default, delegate: HueURLSessionDelegate(), delegateQueue: nil)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let data = data {
                    
                    // Пробуем распарсить ответ
                    do {
                        let config = try JSONDecoder().decode(BridgeConfig.self, from: data)
                        
                        // Обновляем информацию о мосте
                        if let bridgeId = config.bridgeid {
                            self?.currentBridge?.id = bridgeId
                        }
                        if let name = config.name {
                            self?.currentBridge?.name = name
                        }
                        
                        // Пересоздаем API клиент с новым IP если нужно
                        if self?.apiClient.bridgeIP != ip {
                            self?.recreateAPIClient(with: ip)
                        }
                        
                        completion(true)
                    } catch {
                        print("❌ Ошибка парсинга конфигурации моста: \(error)")
                        completion(false)
                    }
                } else {
                    print("❌ Мост недоступен по адресу \(ip): \(error?.localizedDescription ?? "Unknown error")")
                    completion(false)
                }
            }
        }.resume()
    }
    
    /// Переоткрывает мост в сети
    private func rediscoverBridge() {
        print("🔍 Переоткрытие моста в сети...")
        
        // Пытаемся получить Bridge ID из разных источников (в порядке приоритета)
        let bridgeId = currentBridge?.id ?? 
                      UserDefaults.standard.string(forKey: "lastUsedBridgeId") ??
                      UserDefaults.standard.string(forKey: "HueBridgeID") ??
                      HueKeychainManager.shared.getLastBridgeCredentials()?.bridgeId
        
        guard let savedBridgeId = bridgeId, !savedBridgeId.isEmpty else {
            print("❌ Нет сохраненного ID моста для поиска")
            print("   🔍 currentBridge?.id: \(currentBridge?.id ?? "nil")")
            print("   🔍 lastUsedBridgeId: \(UserDefaults.standard.string(forKey: "lastUsedBridgeId") ?? "nil")")
            print("   🔍 HueBridgeID: \(UserDefaults.standard.string(forKey: "HueBridgeID") ?? "nil")")
            print("   🔍 Keychain bridgeId: \(HueKeychainManager.shared.getLastBridgeCredentials()?.bridgeId ?? "nil")")
            
            connectionStatus = .disconnected
            showSetup = true
            return
        }
        
        print("🔍 Ищем мост с ID: \(savedBridgeId)")
        
        // Ищем мост по ID
        searchForSpecificBridge(bridgeId: savedBridgeId) { [weak self] foundBridge in
            if let bridge = foundBridge {
                print("✅ Мост найден по новому адресу: \(bridge.internalipaddress)")
                
                // Обновляем текущий мост
                self?.currentBridge = bridge
                
                // Обновляем все ключи сохранения
                UserDefaults.standard.set(bridge.internalipaddress, forKey: "HueBridgeIP")
                UserDefaults.standard.set(bridge.id, forKey: "HueBridgeID") 
                UserDefaults.standard.set(bridge.id, forKey: "lastUsedBridgeId")
                
                // Переподключаемся с новым IP
                self?.recreateAPIClient(with: bridge.internalipaddress)
                self?.onSuccessfulReconnection()
                
                // Сохраняем новые данные в Keychain
                self?.saveCredentials()
                
            } else {
                print("❌ Мост не найден в сети")
                self?.connectionStatus = .disconnected
                self?.showSetup = true
            }
        }
    }
    
    /// Вызывается при успешном переподключении
    private func onSuccessfulReconnection() {
        connectionStatus = .connected
        showSetup = false
        
        // Перезапускаем event stream
        startEventStream()
        
        // Загружаем актуальные данные
        loadAllData()
        
        // Перезапускаем мониторинг подключения
        startConnectionMonitoring()
        
        print("✅ Переподключение завершено успешно")
    }
    
    // MARK: - Network Path Monitoring (iOS 12+)
    
    @available(iOS 12.0, *)
    private func startNetworkPathMonitoring() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    print("🌐 Сеть доступна")
                    
                    // Если были отключены, пробуем переподключиться
                    if self?.connectionStatus == .disconnected ||
                       self?.connectionStatus == .reconnecting {
                        self?.attemptReconnection()
                    }
                } else {
                    print("📵 Сеть недоступна")
                    
                    // Не отключаемся сразу, ждем восстановления сети
                    if self?.connectionStatus == .connected {
                        self?.connectionStatus = .reconnecting
                    }
                }
            }
        }
        
        monitor.start(queue: queue)
    }
}

// MARK: - URLSession Delegate для самоподписанных сертификатов

private class HueURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, 
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Принимаем самоподписанные сертификаты Hue Bridge
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

// MARK: - Connection Status Extension

extension ConnectionStatus {
    static let reconnecting = ConnectionStatus.connecting // Используем существующий статус
}
