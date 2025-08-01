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
    @Published var lights: [Light] = []
    
    /// Флаг загрузки данных
    @Published var isLoading: Bool = false
    
    /// Текущая ошибка (если есть)
    @Published var error: Error?
    
    /// Выбранная лампа для детального просмотра
    @Published var selectedLight: Light?
    
    /// Фильтр для отображения ламп
    @Published var filter: LightFilter = .all
    
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
    
    /// Включает/выключает лампу
    /// - Parameter light: Лампа для переключения
    func toggleLight(_ light: Light) {
        // Оптимизация: если лампа выключена, отправляем только on:true
        let newState = LightState(
            on: OnState(on: !light.on.on)
        )
        
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Устанавливает яркость лампы
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - brightness: Уровень яркости (0-100)
    func setBrightness(for light: Light, brightness: Double) {
        // Оптимизация: отправляем только изменение яркости
        let newState = LightState(
            dimming: Dimming(brightness: brightness)
        )
        
        updateLight(light.id, state: newState, currentLight: light)
    }
    
    /// Устанавливает цвет лампы
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - color: Цвет в формате SwiftUI Color
    func setColor(for light: Light, color: SwiftUI.Color) {
        let xyColor = convertToXY(color: color, gamutType: light.color_gamut_type)
        // Оптимизация: отправляем только изменение цвета
        let newState = LightState(
            color: HueColor(xy: xyColor)
        )
        
        updateLight(light.id, state: newState, currentLight: light)
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
    
    /// Обновляет локальное состояние лампы
    /// - Parameters:
    ///   - lightId: ID лампы
    ///   - state: Новое состояние
    private func updateLocalLight(_ lightId: String, with state: LightState) {
        guard let index = lights.firstIndex(where: { $0.id == lightId }) else { return }
        
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
        // Получаем компоненты цвета
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        
        // Для SwiftUI используем UIColor/NSColor
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        #elseif canImport(AppKit)
        let nsColor = NSColor(color)
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        #endif
        
        // Применяем гамма-коррекцию (sRGB -> линейный RGB)
        red = (red > 0.04045) ? pow((red + 0.055) / 1.055, 2.4) : (red / 12.92)
        green = (green > 0.04045) ? pow((green + 0.055) / 1.055, 2.4) : (green / 12.92)
        blue = (blue > 0.04045) ? pow((blue + 0.055) / 1.055, 2.4) : (blue / 12.92)
        
        // Конвертируем в XYZ используя Wide RGB D65
        let X = red * 0.4124 + green * 0.3576 + blue * 0.1805
        let Y = red * 0.2126 + green * 0.7152 + blue * 0.0722
        let Z = red * 0.0193 + green * 0.1192 + blue * 0.9505
        
        // Конвертируем в xy
        let sum = X + Y + Z
        var x = sum > 0 ? X / sum : 0
        var y = sum > 0 ? Y / sum : 0
        
        // Проверяем и корректируем для гаммы лампы
        let xyPoint = XYColor(x: x, y: y)
        let gamut = getGamutForType(gamutType)
        
        if !isPointInGamut(xyPoint, gamut: gamut) {
            let corrected = closestPointInGamut(xyPoint, gamut: gamut)
            x = corrected.x
            y = corrected.y
        }
        
        return XYColor(x: x, y: y)
    }
    
    /// Получает треугольник гаммы для типа
    private func getGamutForType(_ type: String?) -> Gamut {
        switch type {
        case "A":
            // Legacy LivingColors (Bloom, Aura, Light Strips, Iris)
            return Gamut(
                red: XYColor(x: 0.704, y: 0.296),
                green: XYColor(x: 0.2151, y: 0.7106),
                blue: XYColor(x: 0.138, y: 0.08)
            )
        case "B":
            // Старые Hue bulbs
            return Gamut(
                red: XYColor(x: 0.675, y: 0.322),
                green: XYColor(x: 0.409, y: 0.518),
                blue: XYColor(x: 0.167, y: 0.04)
            )
        case "C":
            // Новые Hue bulbs
            return Gamut(
                red: XYColor(x: 0.6915, y: 0.3038),
                green: XYColor(x: 0.17, y: 0.7),
                blue: XYColor(x: 0.1532, y: 0.0475)
            )
        default:
            // Дефолтная гамма (полный спектр)
            return Gamut(
                red: XYColor(x: 1.0, y: 0),
                green: XYColor(x: 0.0, y: 1.0),
                blue: XYColor(x: 0.0, y: 0.0)
            )
        }
    }
    
    /// Проверяет, находится ли точка внутри треугольника гаммы
    private func isPointInGamut(_ point: XYColor, gamut: Gamut) -> Bool {
        guard let red = gamut.red,
              let green = gamut.green,
              let blue = gamut.blue else { return true }
        
        let v1 = CGPoint(x: green.x - red.x, y: green.y - red.y)
        let v2 = CGPoint(x: blue.x - red.x, y: blue.y - red.y)
        let q = CGPoint(x: point.x - red.x, y: point.y - red.y)
        
        let s = crossProduct(q, v2) / crossProduct(v1, v2)
        let t = crossProduct(v1, q) / crossProduct(v1, v2)
        
        return (s >= 0.0) && (t >= 0.0) && (s + t <= 1.0)
    }
    
    /// Вычисляет векторное произведение
    private func crossProduct(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return p1.x * p2.y - p1.y * p2.x
    }
    
    /// Находит ближайшую точку внутри гаммы
    private func closestPointInGamut(_ point: XYColor, gamut: Gamut) -> XYColor {
        guard let red = gamut.red,
              let green = gamut.green,
              let blue = gamut.blue else { return point }
        
        // Находим ближайшую точку на каждой стороне треугольника
        let pRG = closestPointOnLine(
            point: point,
            lineStart: red,
            lineEnd: green
        )
        
        let pGB = closestPointOnLine(
            point: point,
            lineStart: green,
            lineEnd: blue
        )
        
        let pBR = closestPointOnLine(
            point: point,
            lineStart: blue,
            lineEnd: red
        )
        
        // Вычисляем расстояния
        let dRG = distance(from: point, to: pRG)
        let dGB = distance(from: point, to: pGB)
        let dBR = distance(from: point, to: pBR)
        
        // Возвращаем ближайшую точку
        if dRG <= dGB && dRG <= dBR {
            return pRG
        } else if dGB <= dBR {
            return pGB
        } else {
            return pBR
        }
    }
    
    /// Находит ближайшую точку на линии
    private func closestPointOnLine(point: XYColor, lineStart: XYColor, lineEnd: XYColor) -> XYColor {
        let ap = CGPoint(x: point.x - lineStart.x, y: point.y - lineStart.y)
        let ab = CGPoint(x: lineEnd.x - lineStart.x, y: lineEnd.y - lineStart.y)
        
        let ab2 = ab.x * ab.x + ab.y * ab.y
        let ap_ab = ap.x * ab.x + ap.y * ab.y
        
        var t = ap_ab / ab2
        t = max(0.0, min(1.0, t))
        
        return XYColor(
            x: lineStart.x + ab.x * t,
            y: lineStart.y + ab.y * t
        )
    }
    
    /// Вычисляет расстояние между точками
    private func distance(from p1: XYColor, to p2: XYColor) -> Double {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Конвертирует XY в RGB (для отображения в UI)
    func convertXYToColor(_ xy: XYColor, brightness: Double = 1.0, gamutType: String? = nil) -> Color {
        let gamut = getGamutForType(gamutType)
        var xyPoint = xy
        
        // Проверяем и корректируем точку в пределах гаммы
        if !isPointInGamut(xyPoint, gamut: gamut) {
            xyPoint = closestPointInGamut(xyPoint, gamut: gamut)
        }
        
        // Конвертируем xy в XYZ
        let z = 1.0 - xyPoint.x - xyPoint.y
        let Y = brightness
        let X = (Y / xyPoint.y) * xyPoint.x
        let Z = (Y / xyPoint.y) * z
        
        // Конвертируем XYZ в RGB (sRGB D65)
        var r = X * 1.656492 - Y * 0.354851 - Z * 0.255038
        var g = -X * 0.707196 + Y * 1.655397 + Z * 0.036152
        var b = X * 0.051713 - Y * 0.121364 + Z * 1.011530
        
        // Ограничиваем значения если они выходят за пределы
        if r > b && r > g && r > 1.0 {
            g = g / r
            b = b / r
            r = 1.0
        } else if g > b && g > r && g > 1.0 {
            r = r / g
            b = b / g
            g = 1.0
        } else if b > r && b > g && b > 1.0 {
            r = r / b
            g = g / b
            b = 1.0
        }
        
        // Применяем обратную гамма-коррекцию (линейный RGB -> sRGB)
        r = r <= 0.0031308 ? 12.92 * r : (1.0 + 0.055) * pow(r, (1.0 / 2.4)) - 0.055
        g = g <= 0.0031308 ? 12.92 * g : (1.0 + 0.055) * pow(g, (1.0 / 2.4)) - 0.055
        b = b <= 0.0031308 ? 12.92 * b : (1.0 + 0.055) * pow(b, (1.0 / 2.4)) - 0.055
        
        // Финальная проверка диапазона
        r = max(0, min(1, r))
        g = max(0, min(1, g))
        b = max(0, min(1, b))
        
        return Color(red: r, green: g, blue: b)
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


