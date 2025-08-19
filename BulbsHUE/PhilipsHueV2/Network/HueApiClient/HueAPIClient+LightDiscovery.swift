//
//  HueAPIClient+LightDiscovery.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Serial Number Search (Simplified)
    
    /// Добавляет лампу по серийному номеру - возвращает ВСЕ лампы для выбора пользователем
    func addLightBySerialNumber(_ serialNumber: String) -> AnyPublisher<[Light], Error> {
        let cleanSerial = serialNumber.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        print("🔍 Поиск лампы по серийному номеру: \(cleanSerial)")
        print("📋 СТРАТЕГИЯ: Показываем все лампы, запускаем мигание целевой лампы")
        
        // Сначала инициируем поиск через API v1 чтобы лампа мигнула
        return initiateSearchV1(serial: cleanSerial)
            .handleEvents(receiveOutput: { success in
                print("📡 API v1 поиск инициирован: \(success ? "✅ успешно" : "❌ ошибка")")
                if success {
                    print("💡 Лампа с серийным номером \(cleanSerial) должна мигать СЕЙЧАС!")
                    print("👆 Пользователю нужно нажать на мигающую лампу в списке")
                }
            })
            .flatMap { [weak self] _ -> AnyPublisher<[Light], Error> in
                guard let self = self else {
                    return Fail(error: HueAPIError.unknown("Self is nil"))
                        .eraseToAnyPublisher()
                }
                
                // Возвращаем ВСЕ лампы для выбора пользователем
                print("📱 Загружаем все лампы для отображения пользователю...")
                return self.getAllLightsV2HTTPS()
            }
            .eraseToAnyPublisher()
    }
    
    /// Подтверждает выбор лампы пользователем и сохраняет маппинг
    func confirmLightSelection(_ light: Light, forSerialNumber serialNumber: String) {
        let cleanSerial = serialNumber.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        print("✅ Пользователь выбрал лампу: \(light.metadata.name)")
        print("🔗 Привязываем серийный номер \(cleanSerial) к лампе \(light.id)")
        
        // Сохраняем маппинг
        saveSerialMapping(serial: cleanSerial, lightId: light.id)
        
        // Мигаем выбранной лампой для подтверждения
        _ = identifyLight(id: light.id)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("⚠️ Ошибка при мигании подтверждения: \(error)")
                    }
                },
                receiveValue: { success in
                    if success {
                        print("💡 Лампа мигнула для подтверждения выбора")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    /// Инициирует поиск через API v1 для мигания лампы
    private func initiateSearchV1(serial: String) -> AnyPublisher<Bool, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Отправляем серийный номер для целевого поиска
        let body: [String: Any] = ["deviceid": [serial]]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: HueAPIError.unknown("Failed to serialize request"))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HueAPIError.unknown("Invalid response")
                }
                
                print("📡 v1 Search initiation response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    return true
                } else {
                    print("⚠️ API v1 поиск вернул статус: \(httpResponse.statusCode)")
                    return false
                }
            }
            .mapError { HueAPIError.networkError($0) }
            .eraseToAnyPublisher()
    }
    
    /// Сохраняет маппинг серийного номера к ID лампы
    private func saveSerialMapping(serial: String, lightId: String) {
        let key = "SerialMapping_\(serial)"
        UserDefaults.standard.set(lightId, forKey: key)
        print("💾 Сохранен маппинг: \(serial) → \(lightId)")
    }
    
    /// Получает ID лампы по серийному номеру из сохраненного маппинга
    private func getLightIdBySerial(_ serial: String) -> String? {
        let key = "SerialMapping_\(serial)"
        return UserDefaults.standard.string(forKey: key)
    }
    
    /// Мигает лампой для подтверждения (API v2)
    func identifyLight(id: String) -> AnyPublisher<Bool, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://\(bridgeIP)/clip/v2/resource/light/\(id)") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        
        // Используем новый API v2 для identify
        let body: [String: Any] = [
            "identify": ["action": "identify"]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: HueAPIError.unknown("Failed to serialize request"))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HueAPIError.unknown("Invalid response")
                }
                
                if httpResponse.statusCode == 200 {
                    print("💡 Лампа \(id) получила команду мигания")
                    return true
                } else {
                    print("⚠️ Ошибка мигания лампы \(id): статус \(httpResponse.statusCode)")
                    return false
                }
            }
            .mapError { HueAPIError.networkError($0) }
            .eraseToAnyPublisher()
    }
}
