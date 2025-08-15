//
//  HueAPIClient+LightEnrichment.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Light Enrichment with Reachable Status
    
    /// Обогащает лампы v2 данными о reachable статусе из API v1
    internal func enrichLightsWithReachableStatus(_ v2Lights: [Light]) -> AnyPublisher<[Light], Error> {
        print("🔗 Начинаем обогащение ламп статусом reachable...")
        
        // Получаем reachable статус через API v1
        return getLightsV1WithReachableStatus()
            .map { v1Lights in
                var enrichedLights = v2Lights
                
                print("📊 API v1: получено \(v1Lights.count) ламп для проверки статуса")
                
                for i in 0..<enrichedLights.count {
                    let v2Light = enrichedLights[i]
                    
                    // Ищем соответствующую лампу в v1 по различным критериям
                    let matchingV1Light = self.findMatchingV1Light(v2Light: v2Light, v1Lights: v1Lights)
                    
                    if let v1Light = matchingV1Light, let reachable = v1Light.state?.reachable {
                        // Устанавливаем статус связи на основе reachable поля
                        let newStatus: CommunicationStatus = reachable ? .online : .offline
                        enrichedLights[i].communicationStatus = newStatus
                        print("🔗 Лампа '\(v2Light.metadata.name)': reachable=\(reachable) → статус=\(newStatus)")
                    } else {
                        // Если не нашли в v1, оставляем неизвестный статус
                        enrichedLights[i].communicationStatus = .unknown
                        print("❓ Лампа '\(v2Light.metadata.name)': статус неизвестен (не найдена в API v1)")
                    }
                }
                
                let onlineCount = enrichedLights.filter { $0.communicationStatus == .online }.count
                let offlineCount = enrichedLights.filter { $0.communicationStatus == .offline }.count
                let unknownCount = enrichedLights.filter { $0.communicationStatus == .unknown }.count
                
                print("📊 Статистика статусов: online=\(onlineCount), offline=\(offlineCount), unknown=\(unknownCount)")
                
                return enrichedLights
            }
            .catch { error in
                print("⚠️ Не удалось получить reachable статус из v1: \(error)")
                // В случае ошибки возвращаем лампы v2 с неизвестным статусом
                var lightsWithUnknownStatus = v2Lights
                for i in 0..<lightsWithUnknownStatus.count {
                    lightsWithUnknownStatus[i].communicationStatus = .unknown
                    print("❓ Лампа '\(v2Lights[i].metadata.name)': статус установлен как unknown из-за ошибки API v1")
                }
                return Just(lightsWithUnknownStatus)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает данные ламп из API v1 с reachable полем
    func getLightsV1WithReachableStatus() -> AnyPublisher<[String: LightV1WithReachable], Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        print("📡 Запрос reachable статуса через API v1...")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        throw HueAPIError.bridgeNotFound
                    } else if httpResponse.statusCode >= 400 {
                        throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 v1 lights response: \(responseString.prefix(200))...")
                }
                
                return data
            }
            .decode(type: [String: LightV1WithReachable].self, decoder: JSONDecoder())
            .mapError { error in
                print("❌ Ошибка получения v1 lights: \(error)")
                return HueAPIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    /// Находит соответствующую лампу v1 для лампы v2
    func findMatchingV1Light(v2Light: Light, v1Lights: [String: LightV1WithReachable]) -> LightV1WithReachable? {
        // Метод 1: Поиск по имени (самый надежный)
        for (_, v1Light) in v1Lights {
            if let v1Name = v1Light.name, v1Name == v2Light.metadata.name {
                print("✅ Найдено соответствие по имени: \(v1Name)")
                return v1Light
            }
        }
        
        // Метод 2: Поиск по последним символам ID
        let v2IdSuffix = String(v2Light.id.suffix(6)).uppercased()
        for (v1Id, v1Light) in v1Lights {
            if v1Id.uppercased().contains(v2IdSuffix) {
                print("✅ Найдено соответствие по ID suffix: \(v1Id)")
                return v1Light
            }
        }
        
        // Метод 3: Поиск по uniqueid (если доступен)
        if let uniqueid = findUniqueIdFromV2Light(v2Light) {
            for (_, v1Light) in v1Lights {
                if let v1Uniqueid = v1Light.uniqueid, v1Uniqueid.contains(uniqueid) {
                    print("✅ Найдено соответствие по uniqueid: \(uniqueid)")
                    return v1Light
                }
            }
        }
        
        print("❌ Не найдено соответствие для лампы: \(v2Light.metadata.name)")
        return nil
    }
    
    /// Пытается извлечь uniqueid из данных v2 лампы
    internal func findUniqueIdFromV2Light(_ light: Light) -> String? {
        // В API v2 uniqueid может быть спрятан в различных местах
        // Обычно это последняя часть ID лампы
        let lightId = light.id
        
        // Ищем части, похожие на MAC адрес
        let components = lightId.components(separatedBy: "-")
        for component in components {
            if component.count >= 6 && component.range(of: "^[0-9A-Fa-f]+$", options: .regularExpression) != nil {
                return component.uppercased()
            }
        }
        
        return nil
    }
    
    /// Получает список всех ламп через API v1 (может содержать серийные номера)
    /// - Returns: Publisher с информацией о лампах v1
    func getLightsV1() -> AnyPublisher<[String: LightV1Data], Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(applicationKey)/lights") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("📤 HTTP GET запрос v1: \(url)")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                if let httpResponse = response as? HTTPURLResponse {
                    print("📥 HTTP \(httpResponse.statusCode) ответ от \(url)")
                    
                    if httpResponse.statusCode == 404 {
                        throw HueAPIError.bridgeNotFound
                    } else if httpResponse.statusCode >= 400 {
                        throw HueAPIError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 HTTPS тело ответа v1: \(responseString.prefix(500))...")
                }
                
                return data
            }
            .decode(type: [String: LightV1Data].self, decoder: JSONDecoder())
            .mapError { error in
                print("❌ Ошибка получения ламп v1: \(error)")
                return HueAPIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Структуры для API v1 с reachable полем

/// Структура лампы из API v1 с полем reachable
struct LightV1WithReachable: Codable {
    let name: String?
    let uniqueid: String?
    let state: LightV1StateWithReachable?
    let type: String?
    let modelid: String?
    let manufacturername: String?
    let swversion: String?
}

/// Состояние лампы из API v1 с reachable полем
struct LightV1StateWithReachable: Codable {
    let on: Bool?
    let bri: Int?
    let hue: Int?
    let sat: Int?
    let reachable: Bool?  // КЛЮЧЕВОЕ ПОЛЕ для определения доступности
    let alert: String?
    let effect: String?
    let colormode: String?
    let ct: Int?
    let xy: [Double]?
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+LightEnrichment.swift
 
 Описание:
 Расширение HueAPIClient для обогащения данных ламп статусом доступности.
 Комбинирует данные из API v2 и v1 для получения полной информации.
 
 Основные компоненты:
 - enrichLightsWithReachableStatus - обогащение статусом reachable
 - getLightsV1WithReachableStatus - получение ламп v1 с reachable
 - findMatchingV1Light - поиск соответствия между v1 и v2
 - findUniqueIdFromV2Light - извлечение uniqueid из v2
 - getLightsV1 - получение базовых данных v1
 
 Модели:
 - LightV1WithReachable - лампа v1 с полем reachable
 - LightV1StateWithReachable - состояние с reachable
 
 Связанные файлы:
 - HueAPIClient+Lights.swift - основные методы для ламп
 - HueAPIClient+Models.swift - модели данных
 */
