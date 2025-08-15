//
//  HueAPIClient+DeviceMapping.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Структуры для маппинга серийных номеров
    
    /// Информация о сопоставлении устройства
    struct DeviceMapping {
        let deviceId: String        // RID устройства из API v2
        let serialNumber: String?   // Серийный номер с корпуса
        let uniqueId: String?       // Unique ID из API v1 (содержит MAC)
        let macAddress: String?     // Полный MAC/EUI-64 адрес
        let shortMac: String?       // Последние 3 байта MAC (для внутреннего использования)
        let lightId: String?        // ID лампы в системе
        let name: String            // Название лампы
        let v1LightId: String?      // ID лампы в v1 ("/lights/<id>" -> <id>)
    }
    
    // MARK: - Получение маппинга устройств
    
    /// Получает полный маппинг всех устройств (серийники ↔ MAC ↔ lights)
    internal func getDeviceMappings() -> AnyPublisher<[DeviceMapping], Error> {
        print("📊 Получаем маппинг устройств...")
        
        // Параллельно загружаем все необходимые данные
        let devicesPublisher = getV2Devices()
        let zigbeePublisher = getV2ZigbeeConnectivity()
        let v1LightsPublisher = getV1Lights()
        
        return Publishers.Zip3(devicesPublisher, zigbeePublisher, v1LightsPublisher)
            .map { devices, zigbeeConns, v1Lights in
                self.buildDeviceMappings(
                    devices: devices,
                    zigbeeConns: zigbeeConns,
                    v1Lights: v1Lights
                )
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает список устройств через API v2
    internal func getV2Devices() -> AnyPublisher<[V2Device], Error> {
        let endpoint = "/clip/v2/resource/device"
        
        return performRequestHTTPS<V2DevicesResponse>(endpoint: endpoint, method: "GET")
            .map { (response: V2DevicesResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает Zigbee connectivity данные через API v2
    internal func getV2ZigbeeConnectivity() -> AnyPublisher<[V2ZigbeeConn], Error> {
        let endpoint = "/clip/v2/resource/zigbee_connectivity"
        
        return performRequestHTTPS<V2ZigbeeResponse>(endpoint: endpoint, method: "GET")
            .map { (response: V2ZigbeeResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Получает список ламп через API v1 (для uniqueid)
    internal func getV1Lights() -> AnyPublisher<[String: V1Light], Error> {
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
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [String: V1Light].self, decoder: JSONDecoder())
            .mapError { error in
                print("❌ Ошибка получения v1 lights: \(error)")
                return HueAPIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    /// Строит маппинг устройств из полученных данных
    internal func buildDeviceMappings(
        devices: [V2Device],
        zigbeeConns: [V2ZigbeeConn],
        v1Lights: [String: V1Light]
    ) -> [DeviceMapping] {
        
        var mappings: [DeviceMapping] = []
        
        for device in devices {
            // Находим Zigbee connectivity для устройства
            let zigbee = zigbeeConns.first { $0.owner.rid == device.id }
            
            // Извлекаем ID лампы из id_v1
            let v1LightId = extractV1LightId(from: device.id_v1)
            
            // Находим данные из API v1
            let v1Light = v1LightId.flatMap { v1Lights[$0] }
            
            // Извлекаем короткий MAC из uniqueid
            let shortMac = extractShortMac(from: v1Light?.uniqueid)
            
            let mapping = DeviceMapping(
                deviceId: device.id,
                serialNumber: device.serial_number,
                uniqueId: v1Light?.uniqueid,
                macAddress: zigbee?.mac_address ?? zigbee?.mac,
                shortMac: shortMac,
                lightId: extractLightServiceId(from: device.services),
                name: device.metadata?.name ?? "Unknown",
                v1LightId: v1LightId
            )
            
            mappings.append(mapping)
            
            // Логируем для отладки
            if let serial = mapping.serialNumber {
                print("📍 Устройство: \(mapping.name)")
                print("   Серийный номер: \(serial)")
                print("   MAC: \(mapping.macAddress ?? "н/д")")
                print("   Short MAC: \(mapping.shortMac ?? "н/д")")
            }
        }
        
        return mappings
    }
    
    // MARK: - Helper методы
    
    /// Извлекает ID лампы v1 из id_v1
    internal func extractV1LightId(from idV1: String?) -> String? {
        guard let idV1 = idV1 else { return nil }
        // "/lights/3" -> "3"
        return idV1.split(separator: "/").last.map(String.init)
    }
    
    /// Извлекает короткий MAC из uniqueid
    internal func extractShortMac(from uniqueid: String?) -> String? {
        guard let uniqueid = uniqueid else { return nil }
        // "00:17:88:01:10:3e:5f:86-0b" -> "3e5f86"
        let macPart = uniqueid.split(separator: "-").first ?? ""
        let bytes = macPart.split(separator: ":")
        guard bytes.count >= 3 else { return nil }
        return bytes.suffix(3).joined().lowercased()
    }
    
    /// Извлекает ID light сервиса из списка сервисов
    internal func extractLightServiceId(from services: [V2Service]?) -> String? {
        return services?.first { $0.rtype == "light" }?.rid
    }
}

// MARK: - Entertainment Configuration

extension HueAPIClient {
    
    /// Создает Entertainment Configuration
    func createEntertainmentConfiguration(
        name: String,
        lights: [String],
        positions: [Position3D]
    ) -> AnyPublisher<EntertainmentConfiguration, Error> {
        let endpoint = "/clip/v2/resource/entertainment_configuration"
        
        var config = EntertainmentConfiguration()
        config.metadata.name = name
        
        // Создаем каналы для каждой лампы
        config.channels = lights.enumerated().map { index, lightId in
            var channel = EntertainmentChannel()
            channel.channel_id = index
            channel.position = positions[safe: index] ?? Position3D(x: 0, y: 0, z: 0)
            channel.members = [
                ChannelMember(
                    service: ResourceIdentifier(rid: lightId, rtype: "light"),
                    index: 0
                )
            ]
            return channel
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(config)
            
            return performRequestHTTPS<EntertainmentConfiguration>(endpoint: endpoint, method: "POST", body: data)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
}

// MARK: - Safe Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+DeviceMapping.swift
 
 Описание:
 Расширение HueAPIClient для маппинга устройств и работы с Entertainment Configuration.
 Обеспечивает связь между серийными номерами, MAC адресами и ID ламп.
 
 Основные компоненты:
 - DeviceMapping - структура для хранения маппинга
 - getDeviceMappings - получение полного маппинга
 - getV2Devices - получение устройств v2
 - getV2ZigbeeConnectivity - получение Zigbee данных
 - getV1Lights - получение ламп v1
 - buildDeviceMappings - построение маппинга
 - createEntertainmentConfiguration - создание Entertainment конфигурации
 
 Helper методы:
 - extractV1LightId - извлечение ID v1
 - extractShortMac - извлечение короткого MAC
 - extractLightServiceId - извлечение ID сервиса
 
 Зависимости:
 - HueAPIClient базовый класс
 - V2Device, V2ZigbeeConn, V1Light модели
 - performRequestHTTPS для сетевых запросов
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Models.swift - модели данных
 - HueAPIClient+LightDiscovery.swift - обнаружение ламп
 */
