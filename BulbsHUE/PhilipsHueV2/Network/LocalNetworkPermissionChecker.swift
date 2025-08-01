//
//  LocalNetworkPermissionChecker.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 31.07.2025.
//

import Network
import Foundation

/// Утилита для проверки доступа к локальной сети
@available(iOS 14.0, *)
class LocalNetworkPermissionChecker {
    
    private var completion: ((Bool) -> Void)?
    private var connection: NWConnection?
    
    /// Проверяет доступ к локальной сети
    /// ИСПРАВЛЕНИЕ: Улучшенная проверка для iOS 17+ совместимости
    func checkLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        // Создаем тестовое подключение к локальному адресу (роутер)
        let host = NWEndpoint.Host("192.168.1.1")
        let port = NWEndpoint.Port(80)
        
        // Используем простую UDP конфигурацию
        let parameters = NWParameters.udp
        
        connection = NWConnection(host: host, port: port, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ Доступ к локальной сети разрешен")
                self?.cleanup()
                completion(true)
                
            case .failed(let error):
                if let nwError = error as? NWError {
                    switch nwError {
                    case .posix(let code) where code == .ENETUNREACH:
                        print("🚫 Доступ к локальной сети запрещен")
                        self?.cleanup()
                        completion(false)
                    default:
                        // Другие ошибки не обязательно означают отсутствие разрешения
                        print("⚠️ Сетевая ошибка: \(error)")
                        self?.cleanup()
                        completion(true) // Предполагаем что разрешение есть
                    }
                } else {
                    self?.cleanup()
                    completion(true)
                }
                
            case .waiting(let error):
                print("⏳ Ожидание сети: \(error)")
                // Проверяем специфичную ошибку локальной сети
                if error.localizedDescription.contains("Local network") {
                    print("🚫 Требуется разрешение локальной сети")
                    self?.cleanup()
                    completion(false)
                }
                
            default:
                break
            }
        }
        
        connection?.start(queue: .main)
        
        // Таймаут проверки
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.cleanup()
            completion(true) // По умолчанию предполагаем что разрешение есть
        }
    }
    
    private func cleanup() {
        connection?.cancel()
        connection = nil
        completion = nil
    }
}
