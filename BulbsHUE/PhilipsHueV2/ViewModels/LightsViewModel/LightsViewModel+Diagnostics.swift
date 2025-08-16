//
//  LightsViewModel+Diagnostics.swift
//  BulbsHUE
//
//  Диагностические методы для отладки поиска ламп
//

import Foundation
import Combine

extension LightsViewModel {
    
    /// Запускает полную диагностику системы поиска ламп
    /// Используется для отладки проблем в разных регионах (например, Канада)
    func runSearchDiagnostics(completion: @escaping (String) -> Void) {
        print("🔍 Запуск диагностики поиска ламп...")
        
        apiClient.runLightSearchDiagnostics()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion("❌ Ошибка диагностики: \(error)")
                    }
                },
                receiveValue: { diagnosticReport in
                    print(diagnosticReport)
                    completion(diagnosticReport)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Выводит текущее состояние системы в консоль
    func printSystemState() {
        print("\n📊 ТЕКУЩЕЕ СОСТОЯНИЕ СИСТЕМЫ:")
        print("============================")
        print("🔌 Подключение: \(apiClient.hasValidConnection() ? "✅ Активно" : "❌ Нет подключения")")
        print("💡 Всего ламп: \(lights.count)")
        print("🆕 Найдено через сеть: \(networkFoundLights.count)")
        print("🔢 Найдено по серийному номеру: \(serialNumberFoundLights.count)")
        
        if !lights.isEmpty {
            print("\n📋 Список ламп:")
            for (index, light) in lights.enumerated() {
                let status = light.isReachable ? "✅" : "❌"
                print("  \(index + 1). \(light.metadata.name) \(status)")
                print("     ID: \(light.id)")
                print("     Новая: \(light.isNewLight ? "Да" : "Нет")")
            }
        }
        
        print("\n💡 Совет: Используйте runSearchDiagnostics() для детальной диагностики")
        print("============================\n")
    }
    
    /// Тестирует поиск ламп с подробными логами
    func testNetworkSearchWithLogs(completion: @escaping (Bool, String) -> Void) {
        print("\n🧪 ТЕСТ ПОИСКА ЛАМП ЧЕРЕЗ СЕТЬ")
        print("==============================")
        
        var testLog = ""
        let startTime = Date()
        
        // Шаг 1: Проверка подключения
        testLog += "1️⃣ Проверка подключения к мосту...\n"
        guard apiClient.hasValidConnection() else {
            testLog += "❌ Нет подключения к мосту\n"
            completion(false, testLog)
            return
        }
        testLog += "✅ Подключение активно\n\n"
        
        // Шаг 2: Получение текущих ламп
        testLog += "2️⃣ Получение текущего списка ламп...\n"
        let existingCount = lights.count
        testLog += "Найдено существующих ламп: \(existingCount)\n\n"
        
        // Шаг 3: Запуск поиска
        testLog += "3️⃣ Запуск поиска новых ламп...\n"
        testLog += "⏱ Это займет около 40 секунд...\n"
        
        searchForNewLights { [weak self] newLights in
            guard let self = self else { return }
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            testLog += "\n4️⃣ Результаты поиска:\n"
            testLog += "Время выполнения: \(String(format: "%.1f", duration)) секунд\n"
            testLog += "Найдено новых ламп: \(newLights.count)\n"
            
            if newLights.isEmpty {
                testLog += "\n⚠️ Новые лампы не найдены. Возможные причины:\n"
                testLog += "• Все лампы уже добавлены в систему\n"
                testLog += "• Новые лампы не включены или находятся далеко\n"
                testLog += "• Требуется сброс лампы (5 раз вкл/выкл)\n"
                testLog += "• Проблемы с Zigbee каналом\n"
            } else {
                testLog += "\n✅ Найденные лампы:\n"
                for (index, light) in newLights.enumerated() {
                    testLog += "\(index + 1). \(light.metadata.name) (ID: \(light.id))\n"
                }
            }
            
            testLog += "\n5️⃣ Проверка состояния после поиска:\n"
            testLog += "Всего ламп в системе: \(self.lights.count)\n"
            testLog += "==============================\n"
            
            completion(!newLights.isEmpty, testLog)
        }
    }
}
