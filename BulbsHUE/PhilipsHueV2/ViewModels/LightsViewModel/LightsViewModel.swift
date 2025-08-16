//
//  LightsViewModel.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import Foundation
import Combine
import SwiftUI
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// ViewModel для управления лампами
/// Обрабатывает бизнес-логику и взаимодействие с API
class LightsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Список всех ламп в системе
    @Published var lights: [Light] = [] {
        didSet {
            updateLightsDictionary()
        }
    }
    
    /// Словарь для быстрого поиска ламп по ID
    internal var lightsDict: [String: Int] = [:]
    
    /// Флаг загрузки данных
    @Published var isLoading: Bool = false
    
    /// Текущая ошибка (если есть)
    @Published var error: Error?
    
    /// Выбранная лампа для детального просмотра
    @Published var selectedLight: Light?
    
    /// Фильтр для отображения ламп
    @Published var filter: LightFilter = .all
    
    /// Лампы найденные по серийному номеру (отдельно от основного списка)
    @Published var serialNumberFoundLights: [Light] = []
    
    /// Лампы найденные через сетевой поиск (v1 scan)
    @Published var networkFoundLights: [Light] = []
    
    // MARK: - Internal Properties
    
    /// Клиент для работы с API
    internal let apiClient: HueAPIClient
    
    /// Набор подписок Combine
    internal var cancellables = Set<AnyCancellable>()
    
    /// Счетчик активных запросов для предотвращения перегрузки
    internal var activeRequests = 0
    internal let maxActiveRequests = 5
    
    /// Таймер для периодического обновления (устаревший подход)
    internal var refreshTimer: Timer?
    
    /// Подписка на поток событий
    internal var eventStreamCancellable: AnyCancellable?
    
    /// Debouncing для обновления яркости
    internal var brightnessUpdateWorkItem: DispatchWorkItem?
    
    /// Debouncing для обновления цвета
    internal var colorUpdateWorkItem: DispatchWorkItem?
    
    // MARK: - Initialization
    
    /// Инициализирует ViewModel с API клиентом
    /// - Parameter apiClient: Настроенный клиент Hue API
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
        setupBindings()
        apiClient.setLightsViewModel(self)
    }
    
    // MARK: - Internal Methods
    
    /// Обновляет словарь для быстрого поиска ламп
    internal func updateLightsDictionary() {
        lightsDict.removeAll()
        for (index, light) in lights.enumerated() {
            lightsDict[light.id] = index
        }
    }
    
    /// Обновляет локальное состояние лампы
    internal func updateLocalLight(_ lightId: String, with state: LightState) {
        guard let index = lightsDict[lightId], index < lights.count else { return }
        
        if let on = state.on {
            lights[index].on = on
        }
        
        if let dimming = state.dimming {
            lights[index].dimming = dimming
        }
        
        if let color = state.color {
            lights[index].color = color
        }
        
        if let colorTemp = state.color_temperature {
            lights[index].color_temperature = colorTemp
        }
        
        if let effects = state.effects_v2 {
            lights[index].effects_v2 = effects
        }
    }
    
    /// Настраивает привязки данных
    internal func setupBindings() {
        apiClient.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if case HueAPIError.notAuthenticated = error {
                    print("📝 Требуется авторизация - ждем настройки подключения")
                } else {
                    self?.error = error
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    /// Отфильтрованные лампы
    var filteredLights: [Light] {
        switch filter {
        case .all:
            return lights
        case .on:
            return lights.filter { $0.on.on }
        case .off:
            return lights.filter { !$0.on.on }
        case .color:
            return lights.filter { $0.color != nil }
        case .white:
            return lights.filter { $0.color_temperature != nil && $0.color == nil }
        }
    }
    
    /// Группа 0 - все лампы в системе
    var allLightsGroup: HueGroup {
        HueGroup(
            id: "0",
            type: "grouped_light",
            group_type: "light_group",
            metadata: GroupMetadata(name: "Все лампы")
        )
    }
    
    /// Лампы сгруппированные по комнатам
    var lightsByRoom: [String: [Light]] {
        [:]
    }
    
    /// Статистика использования
    var statistics: LightStatistics {
        LightStatistics(
            total: lights.count,
            on: lights.filter { $0.on.on }.count,
            off: lights.filter { !$0.on.on }.count,
            colorLights: lights.filter { $0.color != nil }.count,
            dimmableLights: lights.filter { $0.dimming != nil }.count,
            unreachable: lights.filter { $0.mode == "streaming" }.count
        )
    }
    
    // MARK: - Memory Management
    
    deinit {
        print("♻️ LightsViewModel деинициализация")
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        refreshTimer?.invalidate()
        refreshTimer = nil
        brightnessUpdateWorkItem?.cancel()
        colorUpdateWorkItem?.cancel()
        stopEventStream()
        lights.removeAll()
        serialNumberFoundLights.removeAll()
        lightsDict.removeAll()
    }
}

/// Фильтр для отображения ламп
enum LightFilter: String, CaseIterable {
    case all = "Все"
    case on = "Включенные"
    case off = "Выключенные"
    case color = "Цветные"
    case white = "Белые"
    
    var icon: String {
        switch self {
        case .all: return "lightbulb"
        case .on: return "lightbulb.fill"
        case .off: return "lightbulb.slash"
        case .color: return "paintpalette"
        case .white: return "sun.max"
        }
    }
}

/// Статистика по лампам
struct LightStatistics {
    let total: Int
    let on: Int
    let off: Int
    let colorLights: Int
    let dimmableLights: Int
    let unreachable: Int
    
    var onPercentage: Double {
        total > 0 ? Double(on) / Double(total) * 100 : 0
    }
    
    var averageBrightness: Double {
        0
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ LightsViewModel.swift
 
 Описание:
 Основной класс ViewModel для управления состоянием ламп Philips Hue.
 Содержит базовые свойства, инициализацию и computed properties.
 
 Основные компоненты:
 - Published свойства для UI binding
 - Internal свойства для работы с API
 - Словарь для быстрого поиска ламп
 - Фильтры и статистика
 
 Использование:
 let viewModel = LightsViewModel(apiClient: apiClient)
 viewModel.loadLights()
 
 Зависимости:
 - HueAPIClient для работы с API
 - SwiftUI/Combine для реактивности
 
 Связанные файлы:
 - LightsViewModel+LightControl.swift - управление состоянием ламп
 - LightsViewModel+SerialNumber.swift - поиск по серийному номеру
 - LightsViewModel+EventStream.swift - обработка событий
 - LightsViewModel+NetworkSearch.swift - сетевой поиск
 */
