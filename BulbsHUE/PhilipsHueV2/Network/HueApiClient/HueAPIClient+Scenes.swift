//
//  HueAPIClient+Scenes.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Scenes Endpoints
    
    /// Получает список всех сцен
    /// - Returns: Combine Publisher со списком сцен
    func getAllScenes() -> AnyPublisher<[HueScene], Error> {
        let endpoint = "/clip/v2/resource/scene"
        return performRequestHTTPS<ScenesResponse>(endpoint: endpoint, method: "GET")
            .map { (response: ScenesResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Активирует сцену
    /// - Parameter sceneId: Уникальный идентификатор сцены
    /// - Returns: Combine Publisher с результатом активации
    func activateScene(sceneId: String) -> AnyPublisher<Bool, Error> {
        let endpoint = "/clip/v2/resource/scene/\(sceneId)"
        
        let body = SceneActivation(recall: RecallAction(action: "active"))
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(body)
            
            return performRequestHTTPS<GenericResponse>(endpoint: endpoint, method: "PUT", body: data)
                .map { (_: GenericResponse) in true }
                .catch { error -> AnyPublisher<Bool, Error> in
                    print("Error activating scene: \(error)")
                    return Just(false)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Создает новую сцену
    /// - Parameters:
    ///   - name: Название сцены
    ///   - lights: Список идентификаторов ламп для сцены
    ///   - room: Идентификатор комнаты (опционально)
    /// - Returns: Combine Publisher с созданной сценой
    func createScene(name: String, lights: [String], room: String? = nil) -> AnyPublisher<HueScene, Error> {
        let endpoint = "/clip/v2/resource/scene"
        
        var scene = HueScene()
        scene.metadata.name = name
        scene.actions = lights.map { lightId in
            HueSceneAction(
                target: ResourceIdentifier(rid: lightId, rtype: "light"),
                action: LightState()
            )
        }
        
        if let room = room {
            scene.group = ResourceIdentifier(rid: room, rtype: "room")
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scene)
            
            return performRequestHTTPS<SceneResponse>(endpoint: endpoint, method: "POST", body: data)
                .map { (response: SceneResponse) in
                    response.data.first ?? HueScene()
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+Scenes.swift
 
 Описание:
 Расширение HueAPIClient для управления сценами освещения.
 
 Основные компоненты:
 - getAllScenes - получение списка всех сцен
 - activateScene - активация сцены
 - createScene - создание новой сцены
 
 Зависимости:
 - HueAPIClient базовый класс
 - HueScene, SceneActivation, RecallAction модели
 - performRequestHTTPS для сетевых запросов
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Networking.swift - сетевые методы
 */
