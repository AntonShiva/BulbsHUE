//
//  GetSavedBridgeUseCase.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

/// Use Case для получения сохраненного моста
/// Управляет загрузкой и проверкой сохраненных подключений
class GetSavedBridgeUseCase {
    
    // MARK: - Dependencies
    
    private let bridgeRepository: BridgeRepository
    
    // MARK: - Initialization
    
    init(bridgeRepository: BridgeRepository) {
        self.bridgeRepository = bridgeRepository
    }
    
    // MARK: - Public Methods
    
    /// Получает сохраненный мост и проверяет его доступность
    /// - Returns: Publisher с сохраненным мостом (если доступен)
    func execute() -> AnyPublisher<BridgeEntity?, Error> {
        print("📱 [GetSavedBridgeUseCase] Загружаем сохраненный мост...")
        
        return bridgeRepository.getSavedBridge()
            .flatMap { [weak self] savedBridge -> AnyPublisher<BridgeEntity?, Error> in
                guard let self = self, let bridge = savedBridge else {
                    print("ℹ️ [GetSavedBridgeUseCase] Нет сохраненного моста")
                    return Just(nil)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                print("📱 [GetSavedBridgeUseCase] Найден сохраненный мост: \(bridge.name)")
                
                // Проверяем доступность сохраненного моста
                return self.bridgeRepository.checkBridgeConnection(bridge)
                    .map { isConnected -> BridgeEntity? in
                        if isConnected {
                            print("✅ [GetSavedBridgeUseCase] Сохраненный мост доступен")
                            
                            // Обновляем время последнего обращения
                            return BridgeEntity(
                                id: bridge.id,
                                name: bridge.name,
                                ipAddress: bridge.ipAddress,
                                modelId: bridge.modelId,
                                swVersion: bridge.swVersion,
                                applicationKey: bridge.applicationKey,
                                isConnected: true,
                                lastSeen: Date()
                            )
                        } else {
                            print("⚠️ [GetSavedBridgeUseCase] Сохраненный мост недоступен")
                            
                            // Возвращаем мост как недоступный
                            return BridgeEntity(
                                id: bridge.id,
                                name: bridge.name,
                                ipAddress: bridge.ipAddress,
                                modelId: bridge.modelId,
                                swVersion: bridge.swVersion,
                                applicationKey: bridge.applicationKey,
                                isConnected: false,
                                lastSeen: bridge.lastSeen
                            )
                        }
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает сохраненный мост без проверки доступности
    /// - Returns: Publisher с сохраненным мостом (если есть)
    func executeWithoutCheck() -> AnyPublisher<BridgeEntity?, Never> {
        print("📱 [GetSavedBridgeUseCase] Загружаем сохраненный мост без проверки...")
        return bridgeRepository.getSavedBridge()
    }
    
    /// Получает все сохраненные мосты
    /// - Returns: Publisher с массивом сохраненных мостов
    func getAllSavedBridges() -> AnyPublisher<[BridgeEntity], Never> {
        print("📱 [GetSavedBridgeUseCase] Загружаем все сохраненные мосты...")
        return bridgeRepository.getAllSavedBridges()
    }
    
    /// Удаляет сохраненный мост
    /// - Returns: Publisher с результатом удаления
    func removeSavedBridge() -> AnyPublisher<Void, Never> {
        print("🗑️ [GetSavedBridgeUseCase] Удаляем сохраненный мост...")
        return bridgeRepository.removeSavedBridge()
    }
}
