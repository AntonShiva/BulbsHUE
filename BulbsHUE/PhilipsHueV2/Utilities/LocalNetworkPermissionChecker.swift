//
//  LocalNetworkPermissionChecker.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 30.07.2025.
//

import Foundation
import Network

/// Проверяет разрешение на доступ к локальной сети в iOS 14+ с правильным ожиданием ответа пользователя
@available(iOS 14.0, *)
class LocalNetworkPermissionChecker: NSObject {
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?
    
    /// Статический метод для проверки разрешения с async/await
    static func checkLocalNetworkPermission() async -> Bool {
        let checker = LocalNetworkPermissionChecker()
        return await checker.requestAuthorization()
    }
    
    /// Асинхронная версия проверки разрешения
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            requestAuthorization { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Проверяет разрешение на локальную сеть через Bonjour сервисы
    /// Это самый надежный способ получить реальный ответ пользователя
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        // Создаем параметры для peer-to-peer соединений
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // Создаем браузер для поиска Bonjour сервисов
        let browser = NWBrowser(for: .bonjour(type: "_bonjour._tcp", domain: nil), using: parameters)
        self.browser = browser
        
        browser.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .failed(let error):
                print("Browser failed: \(error.localizedDescription)")
                self?.cleanup()
                self?.completion?(false)
            case .ready, .cancelled:
                break
            case .waiting(let error):
                print("Local network permission denied: \(error)")
                self?.cleanup()
                self?.completion?(false)
            default:
                break
            }
        }
        
        // Создаем NetService для публикации
        self.netService = NetService(domain: "local.", type: "_lnp._tcp.", name: "LocalNetworkPrivacy", port: 1100)
        self.netService?.delegate = self
        
        // Для корректной работы в фоновых потоках нужно планировать в main runloop
        self.netService?.schedule(in: .main, forMode: .common)
        
        // Запускаем браузер и публикуем сервис
        self.browser?.start(queue: .main)
        self.netService?.publish()
    }
    
    /// Очищает ресурсы
    private func cleanup() {
        self.browser?.cancel()
        self.browser = nil
        self.netService?.stop()
        self.netService = nil
    }
}

@available(iOS 14.0, *)
extension LocalNetworkPermissionChecker: NetServiceDelegate {
    /// Вызывается когда сервис успешно опубликован - значит разрешение получено
    func netServiceDidPublish(_ sender: NetService) {
        print("✅ Local network permission granted")
        cleanup()
        completion?(true)
    }
    
    /// Вызывается если публикация сервиса не удалась
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("❌ NetService publication failed: \(errorDict)")
        cleanup()
        completion?(false)
    }
}

/// Версия для iOS < 14 (заглушка)
class LocalNetworkPermissionCheckerLegacy {
    func checkLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        // В iOS < 14 разрешения локальной сети нет, возвращаем true
        completion(true)
    }
}
