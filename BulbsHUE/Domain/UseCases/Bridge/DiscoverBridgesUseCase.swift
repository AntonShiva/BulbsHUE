//
//  DiscoverBridgesUseCase.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

/// Use Case для поиска мостов Philips Hue
/// Реализует приоритетную последовательную стратегию поиска для максимальной эффективности
///
/// **Стратегия поиска:**
/// 1. mDNS (Bonjour) - самый быстрый локальный поиск
/// 2. Cloud Discovery - надежный интернет поиск через Philips API
/// 3. SSDP - локальный UDP multicast поиск как последний резерв
///
/// **Преимущества:**
/// - Минимальное время поиска (завершается при первом успешном методе)
/// - Экономия ресурсов сети и батареи
/// - Максимальная вероятность найти мост
class DiscoverBridgesUseCase {
    
    // MARK: - Dependencies
    
    private let bridgeRepository: BridgeRepository
    
    // MARK: - Initialization
    
    init(bridgeRepository: BridgeRepository) {
        self.bridgeRepository = bridgeRepository
    }
    
    // MARK: - Public Methods
    
    /// Комплексный поиск мостов используя приоритетную последовательную стратегию
    /// - Returns: Publisher с найденными мостами
    func execute() -> AnyPublisher<[BridgeEntity], Error> {
        print("🔍 [DiscoverBridgesUseCase] Запускаем приоритетный поиск мостов...")
        
        // Стратегия: последовательный поиск с приоритетами для максимальной эффективности
        // 1. mDNS - самый быстрый локальный поиск
        // 2. Cloud Discovery - надежный интернет поиск  
        // 3. SSDP - локальный UDP multicast поиск
        
        return bridgeRepository.discoverBridgesViaMDNS()
            .catch { error -> AnyPublisher<[BridgeEntity], Never> in
                print("❌ [DiscoverBridgesUseCase] mDNS Discovery failed: \(error)")
                return Just([]).eraseToAnyPublisher()
            }
            .flatMap { mdnsBridges -> AnyPublisher<[BridgeEntity], Error> in
                // Если mDNS нашел мосты - завершаем досрочно (самый эффективный метод)
                if !mdnsBridges.isEmpty {
                    print("✅ [DiscoverBridgesUseCase] mDNS нашел \(mdnsBridges.count) мост(ов), завершаем досрочно")
                    return Just(mdnsBridges)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // Если mDNS не нашел - пробуем Cloud Discovery
                print("🔄 [DiscoverBridgesUseCase] mDNS не нашел мостов, пробуем Cloud Discovery...")
                return self.bridgeRepository.discoverBridgesViaPhilips()
                    .catch { error -> AnyPublisher<[BridgeEntity], Never> in
                        print("❌ [DiscoverBridgesUseCase] Cloud Discovery failed: \(error)")
                        return Just([]).eraseToAnyPublisher()
                    }
                    .flatMap { cloudBridges -> AnyPublisher<[BridgeEntity], Error> in
                        // Если Cloud нашел мосты - завершаем
                        if !cloudBridges.isEmpty {
                            print("✅ [DiscoverBridgesUseCase] Cloud Discovery нашел \(cloudBridges.count) мост(ов)")
                            return Just(cloudBridges)
                                .setFailureType(to: Error.self)
                                .eraseToAnyPublisher()
                        }
                        
                        // Если Cloud не нашел - используем SSDP как последний резерв
                        print("🔄 [DiscoverBridgesUseCase] Cloud не нашел мостов, используем SSDP...")
                        return self.bridgeRepository.discoverBridges()
                            .catch { error -> AnyPublisher<[BridgeEntity], Never> in
                                print("❌ [DiscoverBridgesUseCase] SSDP Discovery failed: \(error)")
                                return Just([]).eraseToAnyPublisher()
                            }
                            .map { ssdpBridges in
                                print("✅ [DiscoverBridgesUseCase] SSDP нашел \(ssdpBridges.count) мост(ов)")
                                return ssdpBridges
                            }
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Быстрый поиск только через mDNS (самый быстрый локальный метод)
    /// - Returns: Publisher с найденными мостами
    func executeFast() -> AnyPublisher<[BridgeEntity], Error> {
        print("⚡ [DiscoverBridgesUseCase] Быстрый поиск через mDNS...")
        return bridgeRepository.discoverBridgesViaMDNS()
    }
    
    /// Поиск через облачный сервис Philips
    /// - Returns: Publisher с найденными мостами
    func executeViaCloud() -> AnyPublisher<[BridgeEntity], Error> {
        print("☁️ [DiscoverBridgesUseCase] Поиск через облачный сервис...")
        return bridgeRepository.discoverBridgesViaPhilips()
    }
    
    // MARK: - Private Methods
    
    // Приватные методы больше не нужны - логика дедупликации перенесена в репозиторий
}

