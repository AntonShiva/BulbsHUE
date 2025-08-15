//
//  HueAPIClient+Sensors.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Sensors Endpoints
    
    /// Получает список всех сенсоров
    /// - Returns: Combine Publisher со списком сенсоров
    func getAllSensors() -> AnyPublisher<[HueSensor], Error> {
        let endpoint = "/clip/v2/resource/device"
        return performRequestHTTPS<SensorsResponse>(endpoint: endpoint, method: "GET")
            .map { (response: SensorsResponse) in
                response.data.filter { device in
                    // Фильтруем только устройства с сенсорами
                    device.services?.contains { service in
                        ["motion", "light_level", "temperature", "button"].contains(service.rtype)
                    } ?? false
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает информацию о конкретном сенсоре
    /// - Parameter id: Идентификатор сенсора
    /// - Returns: Combine Publisher с информацией о сенсоре
    func getSensor(id: String) -> AnyPublisher<HueSensor, Error> {
        let endpoint = "/clip/v2/resource/device/\(id)"
        return performRequestHTTPS<SensorResponse>(endpoint: endpoint, method: "GET")
            .map { (response: SensorResponse) in
                response.data.first ?? HueSensor()
            }
            .eraseToAnyPublisher()
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+Sensors.swift
 
 Описание:
 Расширение HueAPIClient для управления сенсорами.
 
 Основные компоненты:
 - getAllSensors - получение списка всех сенсоров
 - getSensor - получение информации о конкретном сенсоре
 
 Особенности:
 - Фильтрует устройства по типу сервисов (motion, light_level, temperature, button)
 
 Зависимости:
 - HueAPIClient базовый класс
 - HueSensor модель
 - performRequestHTTPS для сетевых запросов
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Networking.swift - сетевые методы
 */
