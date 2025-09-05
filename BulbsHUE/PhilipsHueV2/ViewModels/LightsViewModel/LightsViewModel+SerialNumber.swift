//
//  LightsViewModel+SerialNumber.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//

import Foundation
import Combine

extension LightsViewModel {
    
    // MARK: - Serial Number Search (Simplified)
   
    /// Поиск лампы по серийному номеру - новая простая стратегия
    func addLightBySerialNumber(_ serialNumber: String) {
        print("🔍 Поиск лампы по серийному номеру: \(serialNumber)")
        
        guard isValidSerialNumber(serialNumber) else {
            print("❌ Неверный формат серийного номера")
            error = HueAPIError.unknown("Серийный номер должен содержать 6 символов (0-9, A-Z)")
            return
        }
        
        isLoading = true
        error = nil
        clearSerialNumberFoundLights()
        
        apiClient.addLightBySerialNumber(serialNumber)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    Task { @MainActor in
                        self?.isLoading = false
                        
                        if case .failure(let error) = completion {
                            print("❌ Ошибка добавления лампы: \(error)")
                            self?.error = HueAPIError.unknown("Ошибка поиска лампы: \(error.localizedDescription)")
                            self?.serialNumberFoundLights = []
                        }
                    }
                },
                receiveValue: { [weak self] foundLights in
                    guard let self = self else { return }
                    
                    Task { @MainActor in
                        print("🔄 Обновляем UI с найденными лампами: \(foundLights.count)")
                        
                        self.isLoading = false
                        
                        if !foundLights.isEmpty {
                            print("✅ Загружены лампы для выбора: \(foundLights.count)")
                            
                            // Показываем ВСЕ лампы для выбора пользователем
                            self.serialNumberFoundLights = foundLights
                            
                            // Обновляем основной список если есть новые лампы
                            for light in foundLights {
                                if !self.lights.contains(where: { $0.id == light.id }) {
                                    self.lights.append(light)
                                    print("📝 Добавлена новая лампа в основной список: \(light.metadata.name)")
                                }
                            }
                            
                            print("📱 Показываем список ламп для выбора пользователем")
                        } else {
                            print("❌ Нет доступных ламп")
                            self.error = HueAPIError.unknown("Лампы не найдены. Проверьте подключение к мосту.")
                            self.serialNumberFoundLights = []
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    /// Проверяет валидность серийного номера (6 символов A-Z, 0-9)
    func isValidSerialNumber(_ serialNumber: String) -> Bool {
        let cleanSerial = serialNumber.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        return cleanSerial.count == 6 && cleanSerial.allSatisfy { char in
            char.isLetter || char.isNumber
        }
    }
    
    /// Добавляет найденную лампу в список
    func addSerialNumberFoundLight(_ light: Light) {
        serialNumberFoundLights.append(light)
    }
    
    /// Очищает список найденных ламп по серийному номеру
    func clearSerialNumberFoundLights() {
        serialNumberFoundLights = []
    }
    
    /// Принудительно останавливает поиск по серийному номеру
    func forceStopSerialNumberSearch() {
        isLoading = false
        cancellables.removeAll()
    }
}