//
//  HueAPIClient+Groups.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Groups (Rooms/Zones) Endpoints
    
    /// Получает список всех групп (комнат и зон)
    /// - Returns: Combine Publisher со списком групп
    func getAllGroups() -> AnyPublisher<[HueGroup], Error> {
        let endpoint = "/clip/v2/resource/grouped_light"
        return performRequestHTTPS<GroupsResponse>(endpoint: endpoint, method: "GET")
            .map { (response: GroupsResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Обновляет состояние группы ламп с учетом ограничений производительности
    /// - Parameters:
    ///   - id: Идентификатор группы
    ///   - state: Новое состояние для всех ламп в группе
    /// - Returns: Combine Publisher с результатом операции
    func updateGroup(id: String, state: GroupState) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            self?.throttleQueue.async {
                guard let self = self else {
                    promise(.failure(HueAPIError.invalidResponse))
                    return
                }
                
                // Проверяем ограничение скорости для groups (1 команда в секунду)
                let now = Date()
                let timeSinceLastRequest = now.timeIntervalSince(self.lastGroupRequestTime)
                
                if timeSinceLastRequest < self.groupRequestInterval {
                    // Ждем оставшееся время
                    let delay = self.groupRequestInterval - timeSinceLastRequest
                    Thread.sleep(forTimeInterval: delay)
                }
                
                self.lastGroupRequestTime = Date()
                
                let endpoint = "/clip/v2/resource/grouped_light/\(id)"
                
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(state)
                    
                    self.performRequestHTTPS<GenericResponse>(endpoint: endpoint, method: "PUT", body: data)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    print("Error updating group: \(error)")
                                    promise(.success(false))
                                } else {
                                    promise(.success(true))
                                }
                            },
                            receiveValue: { (_: GenericResponse) in
                                promise(.success(true))
                            }
                        )
                        .store(in: &self.cancellables)
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+Groups.swift
 
 Описание:
 Расширение HueAPIClient для управления группами ламп (комнатами и зонами).
 
 Основные компоненты:
 - getAllGroups - получение списка всех групп
 - updateGroup - обновление состояния группы с ограничением скорости
 
 Особенности:
 - Ограничение скорости: максимум 1 команда в секунду для групп
 - Использует throttleQueue для управления очередью запросов
 
 Зависимости:
 - HueAPIClient базовый класс
 - HueGroup, GroupState модели
 - performRequestHTTPS для сетевых запросов
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Networking.swift - сетевые методы
 */
