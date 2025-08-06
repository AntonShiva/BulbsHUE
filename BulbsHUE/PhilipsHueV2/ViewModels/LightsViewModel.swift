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
            // Обновляем словарь для быстрого поиска при изменении массива
            updateLightsDictionary()
        }
    }
    
    /// Словарь для быстрого поиска ламп по ID
    private var lightsDict: [String: Int] = [:]
    
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
    
    // MARK: - Private Properties
    
    /// Клиент для работы с API
    private let apiClient: HueAPIClient
    
    /// Набор подписок Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Performance Properties
    
    /// Счетчик активных запросов для предотвращения перегрузки
    private var activeRequests = 0
    private let maxActiveRequests = 5
    
    /// Таймер для периодического обновления (устаревший подход)
    private var refreshTimer: Timer?
    
    /// Подписка на поток событий
    private var eventStreamCancellable: AnyCancellable?
    
    /// Debouncing для обновления яркости
    private var brightnessUpdateWorkItem: DispatchWorkItem?
    
    /// Debouncing для обновления цвета
    private var colorUpdateWorkItem: DispatchWorkItem?
    
    // MARK: - Initialization
    
    /// Инициализирует ViewModel с API клиентом
    /// - Parameter apiClient: Настроенный клиент Hue API
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Загружает список всех ламп
    func loadLights() {
        isLoading = true
        error = nil
        
        print("🚀 Загружаем лампы через API v2 HTTPS...")
        
        apiClient.getAllLights()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ Ошибка загрузки ламп: \(error)")
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] lights in
                    print("✅ Загружено \(lights.count) ламп")
                    self?.lights = lights
                }
            )
            .store(in: &cancellables)
    }
    
    /// Добавляет найденную лампу в список (для поиска по серийному номеру)
    /// - Parameter light: Найденная лампа для добавления
    func addFoundLight(_ light: Light) {
        print("💡 Добавляем найденную лампу: \(light.metadata.name)")
        
        // Проверяем, нет ли уже такой лампы в списке
        if !lights.contains(where: { $0.id == light.id }) {
            lights.append(light)
            print("✅ Лампа добавлена в список найденных ламп")
        } else {
            print("⚠️ Лампа с таким ID уже существует в списке")
        }
    }
    
    /// Добавляет лампу найденную по серийному номеру в отдельный список
    /// - Parameter light: Лампа найденная по серийному номеру
    func addSerialNumberFoundLight(_ light: Light) {
        print("🔍 Добавляем лампу найденную по серийному номеру: \(light.metadata.name)")
        
        // Очищаем предыдущий результат и добавляем только эту лампу
        serialNumberFoundLights = [light]
        print("✅ Лампа по серийному номеру добавлена")
    }
    
    /// Очищает список ламп найденных по серийному номеру
    func clearSerialNumberFoundLights() {
        serialNumberFoundLights = []
    }
    
    /// Создает новый Light объект на основе серийного номера
    /// - Parameter serialNumber: Серийный номер лампы (должен быть 6 символов)
    /// - Returns: Новый Light объект
    static func createLightFromSerialNumber(_ serialNumber: String) -> Light {
        let cleanSerialNumber = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let lightId = "light_\(cleanSerialNumber)"
        let lightName = "Hue Bulb \(cleanSerialNumber)"
        
        return Light(
            id: lightId,
            type: "light",
            metadata: LightMetadata(
                name: lightName,
                archetype: "desk_lamp"
            ),
            on: OnState(on: false),
            dimming: Dimming(brightness: 100),
            color: HueColor(
                xy: XYColor(x: 0.3, y: 0.3),
                gamut: Gamut(
                    red: XYColor(x: 0.7, y: 0.3),
                    green: XYColor(x: 0.17, y: 0.7),
                    blue: XYColor(x: 0.15, y: 0.06)
                ),
                gamut_type: "C"
            )
        )
    }
    
    /// Валидирует серийный номер Philips Hue (должен быть 6 символов)
    /// - Parameter serialNumber: Серийный номер для проверки
    /// - Returns: true если серийный номер валидный
    static func isValidSerialNumber(_ serialNumber: String) -> Bool {
        let cleanSerial = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanSerial.count == 6 && cleanSerial.allSatisfy { $0.isHexDigit }
    }
    
    /// Включает/выключает лампу
    /// - Parameter light: Лампа для переключения
    func toggleLight(_ light: Light) {
        // Оптимизация: если лампа выключена, отправляем только on:true
        let newState = LightState(
            on: OnState(on: !light.on.on)
        )
        
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Устанавливает яркость лампы с debouncing
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - brightness: Уровень яркости (0-100)
    func setBrightness(for light: Light, brightness: Double) {
        // Отменяем предыдущий запрос если он есть
        brightnessUpdateWorkItem?.cancel()
        
        // Создаем новую задачу с задержкой
        let workItem = DispatchWorkItem { [weak self] in
            let newState = LightState(
                dimming: Dimming(brightness: brightness)
            )
            self?.updateLight(light.id, state: newState, currentLight: light)
        }
        
        // Сохраняем ссылку на задачу
        brightnessUpdateWorkItem = workItem
        
        // Выполняем через 250мс
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
    
    /// Устанавливает цвет лампы с debouncing
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - color: Цвет в формате SwiftUI Color
    func setColor(for light: Light, color: SwiftUI.Color) {
        // Отменяем предыдущий запрос если он есть
        colorUpdateWorkItem?.cancel()
        
        // Создаем новую задачу с задержкой
        let workItem = DispatchWorkItem { [weak self] in
            let xyColor = self?.convertToXY(color: color, gamutType: light.color_gamut_type) ?? XYColor(x: 0.3, y: 0.3)
            let newState = LightState(
                color: HueColor(xy: xyColor)
            )
            self?.updateLight(light.id, state: newState, currentLight: light)
        }
        
        // Сохраняем ссылку на задачу
        colorUpdateWorkItem = workItem
        
        // Выполняем через 200мс (быстрее чем яркость для лучшего UX)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    /// Устанавливает цветовую температуру
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - temperature: Температура в Кельвинах (2200-6500)
    func setColorTemperature(for light: Light, temperature: Int) {
        let mirek = 1_000_000 / temperature
        // Оптимизация: отправляем только изменение температуры
        let newState = LightState(
            color_temperature: ColorTemperature(mirek: mirek)
        )
        
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Применяет эффект к лампе
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - effect: Название эффекта (cosmos, enchant, sunbeam, underwater)
    func applyEffect(to light: Light, effect: String) {
        // Оптимизация: отправляем только изменение эффекта
        let newState = LightState(
            effects_v2: EffectsV2(effect: effect)
        )
        
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Обновляет несколько ламп одновременно (используйте группы для синхронизации)
    /// - Parameters:
    ///   - lights: Массив ламп для обновления
    ///   - state: Новое состояние
    func updateMultipleLights(_ lights: [Light], state: LightState) {
        if lights.count > 3 {
            print("Предупреждение: Для синхронного изменения более 3 ламп используйте группы")
        }
        
        for light in lights {
            updateLight(light.id, state: state, currentLight: light)
        }
    }
    
    /// Включает режим оповещения (мигание)
    /// - Parameter light: Лампа для оповещения
    func alertLight(_ light: Light) {
        // В API v2 alert обрабатывается через effects
        applyEffect(to: light, effect: "breathe")
    }
    
    /// Запускает подписку на события (рекомендуемый подход)
    func startEventStream() {
        stopAutoRefresh() // Останавливаем старый метод
        
        eventStreamCancellable = apiClient.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
        
        // Запускаем поток событий
        apiClient.connectToEventStream()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Event stream error: \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    /// Останавливает поток событий
    func stopEventStream() {
        eventStreamCancellable?.cancel()
        apiClient.disconnectEventStream()
    }
    
    /// Запускает автоматическое обновление (устаревший метод, не рекомендуется)
    func startAutoRefresh() {
        stopAutoRefresh()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.loadLights()
        }
    }
    
    /// Останавливает автоматическое обновление
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Private Methods
    
    /// Настраивает привязки данных
    private func setupBindings() {
        // Подписываемся на ошибки от API клиента
        apiClient.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &cancellables)
    }
    
    /// Обрабатывает событие из потока
    private func handleEvent(_ event: HueEvent) {
        guard let eventData = event.data else { return }
        
        for data in eventData {
            switch data.type {
            case "light":
                // Обновляем конкретную лампу
                if let lightId = data.id {
                    updateLocalLightFromEvent(lightId, eventData: data)
                }
            default:
                break
            }
        }
    }
    
    /// Обновляет локальное состояние лампы из события
    private func updateLocalLightFromEvent(_ lightId: String, eventData: EventData) {
        guard let index = lights.firstIndex(where: { $0.id == lightId }) else { return }
        
        if let on = eventData.on {
            lights[index].on = on
        }
        
        if let dimming = eventData.dimming {
            lights[index].dimming = dimming
        }
        
        if let color = eventData.color {
            lights[index].color = color
        }
        
        if let colorTemp = eventData.color_temperature {
            lights[index].color_temperature = colorTemp
        }
    }
    
    /// Обновляет состояние лампы
    /// - Parameters:
    ///   - lightId: ID лампы
    ///   - state: Новое состояние
    ///   - currentLight: Текущее состояние лампы для оптимизации
    private func updateLight(_ lightId: String, state: LightState, currentLight: Light? = nil) {
        guard activeRequests < maxActiveRequests else {
            print("⚠️ Слишком много активных запросов. Подождите.")
            return
        }
        
        activeRequests += 1
        let optimizedState = state.optimizedState(currentLight: currentLight)
        
        print("🚀 Обновляем лампу \(lightId) через API v2 HTTPS...")
        
        apiClient.updateLight(id: lightId, state: optimizedState)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.activeRequests -= 1
                    
                    if case .failure(let error) = completion {
                        self?.error = error
                        print("❌ Не удалось обновить лампу \(lightId): \(error)")
                        
                        // Обработка специфичных ошибок
                        switch error {
                        case HueAPIError.rateLimitExceeded:
                            print("⚠️ Превышен лимит запросов")
                        case HueAPIError.bufferFull:
                            print("⚠️ Буфер моста переполнен")
                        case HueAPIError.notAuthenticated:
                            print("🔐 Проблема с авторизацией")
                        default:
                            break
                        }
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        print("✅ Лампа \(lightId) успешно обновлена")
                        self?.updateLocalLight(lightId, with: optimizedState)
                    } else {
                        print("❌ Не удалось обновить лампу \(lightId)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обновляет словарь для быстрого поиска ламп
    private func updateLightsDictionary() {
        lightsDict.removeAll()
        for (index, light) in lights.enumerated() {
            lightsDict[light.id] = index
        }
    }
    
    /// Обновляет локальное состояние лампы (оптимизированная версия)
    /// - Parameters:
    ///   - lightId: ID лампы
    ///   - state: Новое состояние
    private func updateLocalLight(_ lightId: String, with state: LightState) {
        // Быстрый поиск через словарь вместо firstIndex(where:)
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
    
    /// Конвертирует SwiftUI Color в XY координаты с учетом гаммы лампы
    /// - Parameters:
    ///   - color: Цвет SwiftUI
    ///   - gamutType: Тип цветовой гаммы (A, B, C или nil)
    /// - Returns: XY координаты для Hue API
    private func convertToXY(color: SwiftUI.Color, gamutType: String? = nil) -> XYColor {
        return ColorConversion.convertToXY(color: color, gamutType: gamutType)
    }
    
    /// Конвертирует XY в RGB (для отображения в UI)
    func convertXYToColor(_ xy: XYColor, brightness: Double = 1.0, gamutType: String? = nil) -> Color {
        return ColorConversion.convertXYToColor(xy, brightness: brightness, gamutType: gamutType)
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
        // Здесь должна быть логика группировки по комнатам
        // На основе информации о группах
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
        // Здесь должен быть расчет средней яркости включенных ламп
        0
    }
}



extension LightsViewModel {
    
    /// Ищет новые лампы в сети через Hue Bridge  
    /// ИСПРАВЛЕНИЕ: Используем тот же подход что и loadLights() - без искусственных задержек
    /// Согласно API v2, мост автоматически обнаруживает новые лампы Zigbee при включении питания
    /// - Parameter completion: Callback с найденными лампами
    func searchForNewLights(completion: @escaping ([Light]) -> Void) {
        print("🔍 Начинаем поиск новых ламп...")
        
        // Сохраняем текущий список ламп для сравнения
        let currentLightIds = Set(lights.map { $0.id })
        print("📊 Текущее количество ламп: \(lights.count)")
        
        // ИСПРАВЛЕНИЕ: Используем прямой вызов как в loadLights(), без задержек
        print("📡 Отправляем запрос getAllLights...")
        
        apiClient.getAllLights()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { result in
                        switch result {
                        case .failure(let error):
                            print("❌ Ошибка при получении ламп: \(error)")
                            
                            // Обработка специфичных ошибок iOS 17+
                            if let hueError = error as? HueAPIError {
                                switch hueError {
                                case .bridgeNotFound:
                                    print("🔌 Hue Bridge не найден в сети - проверьте подключение к мосту")
                                case .localNetworkPermissionDenied:
                                    print("🚫 Отсутствует разрешение локальной сети")
                                case .invalidURL:
                                    print("🌐 Неверный URL адрес моста")
                                case .invalidResponse:
                                    print("📡 Неверный ответ от моста")
                                case .httpError(let statusCode):
                                    print("🔗 HTTP ошибка: \(statusCode)")
                                default:
                                    print("⚠️ Другая ошибка API: \(hueError)")
                                }
                            } else {
                                print("⚠️ Неизвестная ошибка: \(error.localizedDescription)")
                            }
                            completion([])
                        case .finished:
                            print("✅ Запрос getAllLights завершен успешно")
                        }
                    },
                    receiveValue: { [weak self] allLights in
                        guard let self = self else {
                            print("❌ LightsViewModel был деинициализирован в receiveValue")
                            completion([])
                            return
                        }
                        
                        print("📊 Получено ламп от API: \(allLights.count)")
                        
                        // Находим новые лампы
                        let newLights = allLights.filter { light in
                            !currentLightIds.contains(light.id)
                        }
                        
                        print("🆕 Найдено новых ламп: \(newLights.count)")
                        for light in newLights {
                            print("  💡 Новая лампа: \(light.metadata.name) (ID: \(light.id))")
                        }
                        
                        // Обновляем локальный список
                        self.lights = allLights
                        
                        // Возвращаем только новые лампы
                        completion(newLights)
                    }
                )
                .store(in: &self.cancellables)
        }
    
    /// Переименовывает лампу
    /// - Parameters:
    ///   - light: Лампа для переименования
    ///   - newName: Новое имя
    func renameLight(_ light: Light, newName: String) {
        var updatedMetadata = light.metadata
        updatedMetadata.name = newName
        
        // В API v2 для изменения метаданных используется отдельный endpoint
        // Здесь упрощенная версия через обновление состояния
        updateLocalLight(light.id, with: LightState())
        
        // Обновляем локально
        if let index = lights.firstIndex(where: { $0.id == light.id }) {
            lights[index].metadata.name = newName
        }
    }
    
    /// Перемещает лампу в комнату
    /// - Parameters:
    ///   - light: Лампа для перемещения
    ///   - roomId: ID комнаты (группы)
    func moveToRoom(_ light: Light, roomId: String) {
        // В API v2 это делается через обновление группы
        // Добавляем лампу в новую группу и удаляем из старой
        // Здесь упрощенная версия
        
        if let index = lights.firstIndex(where: { $0.id == light.id }) {
            lights[index].metadata.archetype = roomId
        }
    }
}


