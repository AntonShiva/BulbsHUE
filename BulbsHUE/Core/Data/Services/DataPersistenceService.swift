//
//  DataPersistenceService.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/11/25.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

/// Сервис для управления персистентным хранением данных через SwiftData
/// Следует принципам SOLID и обеспечивает изоляцию данных
final class DataPersistenceService: ObservableObject {
    
    // MARK: - Properties
    
    /// Модель контейнер SwiftData
    private let modelContainer: ModelContainer
    
    /// Контекст модели для операций с данными
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    // MARK: - Initialization
    
    /// Инициализация сервиса с контейнером SwiftData
    init() {
        do {
            // Конфигурируем схему данных
            let schema = Schema([
                LightDataModel.self,
                // Здесь можно добавить другие модели для настроек
            ])
            
            // Создаем конфигурацию модели
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false, // Сохраняем на диск
                cloudKitDatabase: .none // Пока без iCloud, можно добавить позже
            )
            
            // Создаем контейнер
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("✅ DataPersistenceService инициализирован успешно")
        } catch {
            fatalError("❌ Не удалось инициализировать ModelContainer: \(error)")
        }
    }
    
    // MARK: - Light Management
    
    /// Сохранить или обновить лампу
    /// - Parameters:
    ///   - light: Light модель из API
    ///   - isAssignedToEnvironment: Назначена ли лампа в Environment
    func saveLightData(_ light: Light, isAssignedToEnvironment: Bool = false) {
        Task { @MainActor in
            // Проверяем, существует ли уже эта лампа
            if let existingLight = fetchLightData(by: light.id) {
                // Обновляем существующую
                existingLight.updateFromLight(light)
                existingLight.isAssignedToEnvironment = isAssignedToEnvironment
            } else {
                // Создаем новую
                let lightData = LightDataModel.fromLight(light, isAssignedToEnvironment: isAssignedToEnvironment)
                modelContext.insert(lightData)
            }
            
            saveContext()
        }
    }
    
    /// Получить сохраненную лампу по ID
    /// - Parameter lightId: ID лампы
    /// - Returns: LightDataModel или nil
    func fetchLightData(by lightId: String) -> LightDataModel? {
        let descriptor = FetchDescriptor<LightDataModel>(
            predicate: #Predicate { $0.lightId == lightId }
        )
        
        do {
            let lights = try modelContext.fetch(descriptor)
            return lights.first
        } catch {
            print("❌ Ошибка получения лампы \(lightId): \(error)")
            return nil
        }
    }
    
    /// Получить все лампы, назначенные в Environment
    /// - Returns: Массив Light моделей
    func fetchAssignedLights() -> [Light] {
        let descriptor = FetchDescriptor<LightDataModel>(
            predicate: #Predicate { $0.isAssignedToEnvironment == true },
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            let lightDataModels = try modelContext.fetch(descriptor)
            return lightDataModels.map { $0.toLight() }
        } catch {
            print("❌ Ошибка получения назначенных ламп: \(error)")
            return []
        }
    }
    
    /// Получить все сохраненные лампы
    /// - Returns: Массив Light моделей
    func fetchAllLights() -> [Light] {
        let descriptor = FetchDescriptor<LightDataModel>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        
        do {
            let lightDataModels = try modelContext.fetch(descriptor)
            return lightDataModels.map { $0.toLight() }
        } catch {
            print("❌ Ошибка получения всех ламп: \(error)")
            return []
        }
    }
    
    /// Назначить лампу в Environment (сделать видимой)
    /// - Parameter lightId: ID лампы
    func assignLightToEnvironment(_ lightId: String) {
        Task { @MainActor in
            if let lightData = fetchLightData(by: lightId) {
                lightData.isAssignedToEnvironment = true
                saveContext()
            }
        }
    }
    
    /// Убрать лампу из Environment (скрыть)
    /// - Parameter lightId: ID лампы
    func removeLightFromEnvironment(_ lightId: String) {
        Task { @MainActor in
            if let lightData = fetchLightData(by: lightId) {
                lightData.isAssignedToEnvironment = false
                saveContext()
            }
        }
    }
    
    /// Удалить лампу полностью
    /// - Parameter lightId: ID лампы
    func deleteLightData(_ lightId: String) {
        Task { @MainActor in
            if let lightData = fetchLightData(by: lightId) {
                modelContext.delete(lightData)
                saveContext()
            }
        }
    }
    
    /// Синхронизировать с данными из API
    /// Обновляет существующие лампы и добавляет новые (но не назначенные)
    /// - Parameter apiLights: Лампы из API
    func syncWithAPILights(_ apiLights: [Light]) {
        Task { @MainActor in
            for light in apiLights {
                // Проверяем состояние лампы - включена ли она в сеть
                let isConnected = light.on.on || (light.dimming?.brightness ?? 0) > 0
                
                if let existingLight = fetchLightData(by: light.id) {
                    // Обновляем существующую лампу
                    existingLight.updateFromLight(light)
                    
                    // Если лампа отключена от сети и не назначена, скрываем её
                    if !isConnected && !existingLight.isAssignedToEnvironment {
                        existingLight.isAssignedToEnvironment = false
                    }
                } else if isConnected {
                    // Добавляем новую лампу только если она подключена
                    let lightData = LightDataModel.fromLight(light, isAssignedToEnvironment: false)
                    modelContext.insert(lightData)
                }
            }
            
            saveContext()
        }
    }
    
    // MARK: - Context Management
    
    /// Сохранить контекст
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("❌ Ошибка сохранения контекста: \(error)")
        }
    }
    
    /// Получить ModelContainer для использования в App
    var container: ModelContainer {
        return modelContainer
    }
}

// MARK: - Extensions

extension DataPersistenceService {
    /// Создать mock сервис для превью и тестов
    static func createMock() -> DataPersistenceService {
        return DataPersistenceService()
    }
}