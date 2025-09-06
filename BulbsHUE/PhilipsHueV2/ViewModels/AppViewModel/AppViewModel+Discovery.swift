import Foundation
import Combine

// MARK: - Bridge Discovery

extension AppViewModel {
    
    /// Начинает комплексный поиск мостов с использованием всех доступных методов
    func searchForBridges() {
        print("🚀 Запуск поиска мостов...")
        connectionStatus = ConnectionStatus.searching
        discoveredBridges.removeAll()
        error = nil
        
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
                            self.connectionStatus = ConnectionStatus.disconnected
                            self.error = HueAPIError.localNetworkPermissionDenied
                        }
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Ошибка при запросе разрешения локальной сети: \(error)")
                        self.connectionStatus = ConnectionStatus.disconnected
                        self.error = HueAPIError.localNetworkPermissionDenied
                    }
                }
            }
        } else {
            startDiscoveryProcess()
        }
    }
    
    /// Поиск моста по серийному номеру через N-UPnP
    func discoverBridge(bySerial serial: String, completion: @escaping (Bridge?) -> Void) {
        apiClient.discoverBridgesViaCloud()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { bridges in
                    let foundBridge = bridges.first { bridge in
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
        
        guard let url = URL(string: "https://\(bridge.internalipaddress)/description.xml") else {
            print("❌ Невалидный URL для моста")
            completion(false)
            return
        }
        
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
    
    // MARK: - Private Discovery Methods
    
    private func startDiscoveryProcess() {
        if #available(iOS 12.0, *) {
            let discovery = HueBridgeDiscovery()
            discovery.discoverBridges { [weak self] bridges in
                self?.handleDiscoveryResults(bridges)
            }
        } else {
            self.handleLegacyDiscovery()
        }
    }
    
    private func handleDiscoveryResults(_ bridges: [Bridge]) {
        Task { @MainActor in
            print("📋 Discovery завершен с результатом: \(bridges.count) мостов")
            for bridge in bridges {
                print("  📡 Мост: \(bridge.id) at \(bridge.internalipaddress)")
            }

            let deduped: [Bridge] = bridges.reduce(into: []) { acc, item in
                var normalized = item
                normalized.id = item.normalizedId
                if !acc.contains(where: { $0.normalizedId == normalized.normalizedId ||
                                        $0.internalipaddress == normalized.internalipaddress }) {
                    acc.append(normalized)
                }
            }
            self.discoveredBridges = deduped
            
            if bridges.isEmpty {
                print("❌ Мосты не найдены")
                self.connectionStatus = .disconnected
                #if os(iOS)
                self.error = HueAPIError.localNetworkPermissionDenied
                #endif
            } else {
                print("✅ Найдено мостов (уникальных): \(deduped.count)")
                self.connectionStatus = .discovered
                self.error = nil
                
                // ✅ ИСПРАВЛЕНИЕ: Если найден единственный мост - сразу переходим к подключению
                if deduped.count == 1, let singleBridge = deduped.first {
                    print("🎯 Найден единственный мост, автоматически переходим к подключению")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Небольшая задержка для обновления UI
                        self.connectToBridge(singleBridge)
                    }
                }
            }
        }
    }
    
    private func handleLegacyDiscovery() {
        print("📱 Используем legacy discovery для iOS < 12.0")
        Task { @MainActor in
            self.connectionStatus = .disconnected
            self.error = HueAPIError.bridgeNotFound
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ AppViewModel+Discovery.swift
 
 Описание:
 Расширение AppViewModel для функциональности поиска и обнаружения Hue Bridge в сети.
 Поддерживает множественные методы discovery: cloud, mDNS, IP scan.
 
 Основные компоненты:
 - searchForBridges() - комплексный поиск мостов
 - discoverBridge(bySerial:) - поиск по серийному номеру через N-UPnP
 - validateBridge() - валидация найденного моста
 - Обработка разрешений локальной сети для iOS 14+
 - Дедупликация найденных мостов
 
 Использование:
 appViewModel.searchForBridges()
 appViewModel.discoverBridge(bySerial: "ABC123") { bridge in ... }
 appViewModel.validateBridge(bridge) { isValid in ... }
 
 Зависимости:
 - HueBridgeDiscovery для различных методов поиска
 - LocalNetworkPermissionChecker для iOS 14+
 - HueAPIClient.discoverBridgesViaCloud() для облачного поиска
 
 Связанные файлы:
 - AppViewModel.swift - основной класс
 - HueBridgeDiscovery.swift - реализация методов discovery
 - LocalNetworkPermissionChecker.swift - проверка разрешений
 */
