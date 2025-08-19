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
    
    // MARK: - Published Properties
    
    /// Список ламп назначенных в Environment (для реактивного обновления UI)
    @Published var assignedLights: [Light] = []
    
    /// Статус операций с данными
    @Published var isUpdating: Bool = false
    
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
            
            // Загружаем начальные данные
            loadAssignedLights()
        } catch {
            fatalError("❌ Не удалось инициализировать ModelContainer: \(error)")
        }
    }
    
    // MARK: - Light Management
    
    /// Сохранить или обновить лампу
    /// - Parameters:
    ///   - light: Light модель из API
    ///   - isAssignedToEnvironment: (опц.) Явно установить флаг назначения в Environment
    ///       Если nil — сохраняем текущее значение без изменений (ВАЖНО: не затираем true на false)
    func saveLightData(_ light: Light, isAssignedToEnvironment: Bool? = nil) {
        Task { @MainActor in
            isUpdating = true
            
            // Проверяем, существует ли уже эта лампа
            if let existingLight = fetchLightData(by: light.id) {
                // Обновляем существующую базовыми полями
                existingLight.updateFromLight(light)
                // Если вызов идёт из UI (передан параметр назначения),
                // то это сохранение выбора пользователя: фиксируем userSubtypeName и userSubtypeIcon
                if isAssignedToEnvironment != nil {
                    if let selectedSubtype = light.metadata.userSubtypeName, !selectedSubtype.isEmpty {
                        existingLight.userSubtype = selectedSubtype
                    }
                    if let icon = light.metadata.userSubtypeIcon, !icon.isEmpty {
                        existingLight.userSubtypeIcon = icon
                    }
                }
                // ВАЖНО: не сбрасывать назначение при отсутствующем параметре
                if let isAssignedToEnvironment {
                    existingLight.isAssignedToEnvironment = isAssignedToEnvironment
                }
            } else {
                // Создаем новую с пользовательским подтипом из UI
                let userSubtype = light.metadata.userSubtypeName ?? "Smart Light"
                let userSubtypeIcon = light.metadata.userSubtypeIcon ?? "o2"
                let lightData = LightDataModel(
                    lightId: light.id,
                    name: light.metadata.name,
                    userSubtype: userSubtype,  // ← Пользовательский выбор названия
                    userSubtypeIcon: userSubtypeIcon,  // ← Пользовательский выбор иконки
                    apiArchetype: light.metadata.archetype,         // ← Сохраняем технический архетип, если известен
                    isOn: light.on.on,
                    brightness: light.dimming?.brightness ?? 50.0,
                    colorTemperature: light.color_temperature?.mirek,
                    colorX: light.color?.xy?.x,
                    colorY: light.color?.xy?.y,
                    isAssignedToEnvironment: isAssignedToEnvironment ?? false
                )
                modelContext.insert(lightData)
            }
            
            saveContext()
            
            // Обновляем @Published свойства для UI
            loadAssignedLights()
            
            // Уведомляем компоненты об обновлении данных
            // Определяем тип обновления
            let updateType = (isAssignedToEnvironment != nil) ? "userSubtype" : "status"
            NotificationCenter.default.post(
                name: Notification.Name("LightDataUpdated"), 
                object: nil, 
                userInfo: ["updateType": updateType, "lightId": light.id]
            )
            
            isUpdating = false
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
            return []
        }
    }
    
    /// Назначить лампу в Environment (сделать видимой)
    /// - Parameter lightId: ID лампы
    func assignLightToEnvironment(_ lightId: String) {
        Task { @MainActor in
            isUpdating = true
            
            if let lightData = fetchLightData(by: lightId) {
                lightData.isAssignedToEnvironment = true
                saveContext()
                
                // Обновляем @Published свойства для UI
                loadAssignedLights()
            }
            
            isUpdating = false
        }
    }
    
    /// Убрать лампу из Environment (скрыть)
    /// - Parameter lightId: ID лампы
    func removeLightFromEnvironment(_ lightId: String) {
        Task { @MainActor in
            isUpdating = true
            
            if let lightData = fetchLightData(by: lightId) {
                lightData.isAssignedToEnvironment = false
                saveContext()
                
                // Обновляем @Published свойства для UI
                loadAssignedLights()
            }
            
            isUpdating = false
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
            
            // Обновляем @Published свойства для UI
            loadAssignedLights()
        }
    }
    
    // MARK: - Private Methods
    
    /// Загрузить назначенные лампы в @Published свойство
    private func loadAssignedLights() {
        let descriptor = FetchDescriptor<LightDataModel>(
            predicate: #Predicate { $0.isAssignedToEnvironment == true },
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            let lightDataModels = try modelContext.fetch(descriptor)
            let newLights = lightDataModels.map { $0.toLight() }
            
            // ФИЛЬТР: Показываем только лампы с установленным пользовательским подтипом
            let lightsWithType = newLights.filter { light in
                guard let subtype = light.metadata.userSubtypeName else { return false }
                return !subtype.isEmpty
            }
            
            // Дополнительно: сортируем по имени для стабильности UI
            assignedLights = lightsWithType.sorted { $0.metadata.name.localizedCaseInsensitiveCompare($1.metadata.name) == .orderedAscending }
        } catch {
            assignedLights = []
        }
    }
    
    // MARK: - Context Management
    
    /// Сохранить контекст
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            // Ошибка сохранения контекста
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
    /// Создать mock сервис для превью с тестовыми данными
    static func createMock() -> DataPersistenceService {
        let mockService = DataPersistenceService()
        
        // Создаем моковые лампы для превью
        let mockLights: [Light] = [
            Light(
                id: "mock_light_01",
                type: "light",
                metadata: LightMetadata(name: "Living Room Ceiling", archetype: "TRADITIONAL LAMP"),
                on: OnState(on: true),
                dimming: Dimming(brightness: 85),
                color: nil,
                color_temperature: nil,
                effects: nil,
                effects_v2: nil,
                mode: nil,
                capabilities: nil,
                color_gamut_type: nil,
                color_gamut: nil,
                gradient: nil
            ),
            Light(
                id: "mock_light_02",
                type: "light",
                metadata: LightMetadata(name: "Bedroom Table Lamp", archetype: "SMART BULB"),
                on: OnState(on: false),
                dimming: Dimming(brightness: 0),
                color: nil,
                color_temperature: nil,
                effects: nil,
                effects_v2: nil,
                mode: nil,
                capabilities: nil,
                color_gamut_type: nil,
                color_gamut: nil,
                gradient: nil
            ),
            Light(
                id: "mock_light_03",
                type: "light",
                metadata: LightMetadata(name: "Kitchen Spots", archetype: "LED STRIP"),
                on: OnState(on: true),
                dimming: Dimming(brightness: 65),
                color: nil,
                color_temperature: nil,
                effects: nil,
                effects_v2: nil,
                mode: nil,
                capabilities: nil,
                color_gamut_type: nil,
                color_gamut: nil,
                gradient: nil
            ),
            Light(
                id: "mock_light_04",
                type: "light",
                metadata: LightMetadata(name: "Office Floor Lamp", archetype: "CEILING LAMP"),
                on: OnState(on: true),
                dimming: Dimming(brightness: 45),
                color: nil,
                color_temperature: nil,
                effects: nil,
                effects_v2: nil,
                mode: nil,
                capabilities: nil,
                color_gamut_type: nil,
                color_gamut: nil,
                gradient: nil
            )
        ]
        
        // Добавляем моковые лампы в сервис как назначенные в Environment
        DispatchQueue.main.async {
            for light in mockLights {
                mockService.saveLightData(light, isAssignedToEnvironment: true)
            }
        }
        
        return mockService
    }
}
