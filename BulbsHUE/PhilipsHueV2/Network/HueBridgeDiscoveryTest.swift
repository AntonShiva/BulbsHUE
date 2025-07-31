//
//  HueBridgeDiscoveryTest.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 31.07.2025.
//

import Foundation

/// Простой тест для проверки работы HueBridgeDiscovery
@available(iOS 12.0, *)
class HueBridgeDiscoveryTest {
    
    /// Запускает тест discovery без краша
    static func runTest() {
        print("🧪 Запускаем тест HueBridgeDiscovery...")
        
        let discovery = HueBridgeDiscovery()
        
        discovery.discoverBridges { bridges in
            print("🧪 Тест завершен. Найдено мостов: \(bridges.count)")
            for bridge in bridges {
                print("   - \(bridge.name) (\(bridge.id)) at \(bridge.internalipaddress)")
            }
        }
        
        print("🧪 Тест запущен, ожидаем результаты...")
    }
    
    /// Запускает множественные тесты для проверки на race conditions
    static func runMultipleTests() {
        print("🧪 Запускаем множественные тесты...")
        
        for i in 1...3 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i)) {
                print("🧪 Запуск теста #\(i)")
                let discovery = HueBridgeDiscovery()
                discovery.discoverBridges { bridges in
                    print("🧪 Тест #\(i) завершен: \(bridges.count) мостов")
                }
            }
        }
    }
}