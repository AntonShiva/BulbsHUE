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
        
        // Устанавливаем обратную связь для обновления статуса связи
        apiClient.setLightsViewModel(self)
    }
    
    // MARK: - Public Methods

    /// Загружает список всех ламп с обновлением статуса
        func loadLights() {
            // ИСПРАВЛЕНИЕ: Проверяем наличие подключения перед загрузкой
            guard apiClient.hasValidConnection() else {
                print("⚠️ Нет подключения к мосту - пропускаем загрузку ламп")
                lights = []
                isLoading = false
                return
            }
            
            isLoading = true
            error = nil
            
            print("🚀 Загружаем лампы через API v2 HTTPS с обновлением статуса...")
            
            // Принудительно обновляем статус при каждом запросе
            apiClient.getAllLights()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            print("❌ Ошибка загрузки ламп: \(error)")
                            // ИСПРАВЛЕНИЕ: Не показываем ошибку авторизации при первом запуске
                            if case HueAPIError.notAuthenticated = error {
                                print("📝 Требуется авторизация - ждем настройки подключения")
                            } else {
                                self?.error = error
                            }
                        }
                    },
                    receiveValue: { [weak self] lights in
                        print("✅ Загружено \(lights.count) ламп с актуальным статусом")
                        self?.lights = lights
                    }
                )
                .store(in: &cancellables)
        }
    
    /// Обновляет список ламп с принудительным обновлением статуса reachable
    @MainActor
    func refreshLightsWithStatus() async {
        isLoading = true
        error = nil
        
        print("🔄 Принудительное обновление ламп с проверкой статуса...")
        
        do {
            // Получаем данные ламп с обновленным статусом
            let updatedLights = try await apiClient.getAllLights()
                .eraseToAnyPublisher()
                .asyncValue()
            
            print("✅ Обновлено \(updatedLights.count) ламп с актуальным статусом")
            self.lights = updatedLights
            
        } catch {
            print("❌ Ошибка обновления ламп: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Запускает мониторинг изменений состояния ламп в реальном времени
    func startLightStatusMonitoring() {
        print("🔄 Запускаем мониторинг статуса ламп в реальном времени...")
        setupEventStreamSubscription()
    }
    
    /// Останавливает мониторинг изменений состояния ламп
    func stopLightStatusMonitoring() {
        print("⏹️ Останавливаем мониторинг статуса ламп...")
        apiClient.disconnectEventStream()
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
    

    
    /// Ищет добавленную лампу после сброса
    private func searchForAddedLight(_ serialNumber: String) {
        print("🔍 Ищем добавленную лампу \(serialNumber) в обновленном списке...")
        
        // После перезагрузки списка ламп завершаем
        isLoading = false
    }
    
    /// Добавляет новую лампу по серийному номеру (TouchLink reset + add)
    /// Это процедура сброса и добавления лампы, как в официальном приложении Philips Hue
    /// - Parameter serialNumber: Серийный номер лампы для добавления (6-символьный код)
    /// Поиск лампы по серийному номеру (среди подключенных или новых)
    // Файл: BulbsHUE/PhilipsHueV2/ViewModels/LightsViewModel.swift
    // Найдите метод addLightBySerialNumber (строка ~280)

    func addLightBySerialNumber(_ serialNumber: String) {
        print("🔍 Поиск лампы по серийному номеру: \(serialNumber)")
        
        guard isValidSerialNumber(serialNumber) else {
            print("❌ Неверный формат серийного номера")
            error = HueAPIError.unknown("Серийный номер должен содержать 6 символов (0-9, A-Z)")
            return
        }
        
        isLoading = true
        error = nil
        clearSerialNumberFoundLights()
        
        apiClient.addLightBySerialNumber(serialNumber)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        print("❌ Ошибка добавления лампы: \(error)")
                        self?.handleSerialNumberError(error, serialNumber: serialNumber)
                    }
                },
                receiveValue: { [weak self] foundLights in
                    guard let self = self else { return }
                    
                    if !foundLights.isEmpty {
                        print("✅ Найдено ламп: \(foundLights.count)")
                        
                        // ИСПРАВЛЕНО: НЕ показываем категории автоматически
                        // Только сохраняем найденные лампы
                        self.serialNumberFoundLights = foundLights
                        
                        // Добавляем новые лампы в общий список
                        for light in foundLights {
                            if !self.lights.contains(where: { $0.id == light.id }) {
                                self.lights.append(light)
                                print("   + Добавлена лампа: \(light.metadata.name)")
                            }
                        }
                        
                        // УДАЛЕНО: NavigationManager.shared.showCategoriesSelection(for: firstLight)
                        // Пользователь сам выберет лампу и нажмет кнопку
                        
                    } else {
                        print("❌ Лампы с серийным номером \(serialNumber) не найдены")
                        self.showNotFoundError(for: serialNumber)
                    }
                }
            )
            .store(in: &cancellables)
    }

  
    /// Поиск среди существующих ламп по серийному номеру
    private func findExistingLightBySerial(_ serialNumber: String) -> Light? {
        let cleanSerial = serialNumber.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        print("🔍 Ищем лампу с серийным номером: \(cleanSerial)")
        
        // УДАЛЕНО: Хардкод маппинг
        // Теперь ищем динамически по ID и метаданным
        
        return lights.first { light in
            // Проверяем различные способы идентификации
            let lightId = light.id.uppercased().replacingOccurrences(of: "-", with: "")
            let lightName = light.metadata.name.uppercased()
            
            // Проверяем:
            // 1. ID содержит серийный номер
            // 2. Имя содержит серийный номер
            // 3. Последние 6 символов ID совпадают с серийным номером
            let idContainsSerial = lightId.contains(cleanSerial)
            let nameContainsSerial = lightName.contains(cleanSerial)
            let idEndsWithSerial = lightId.count >= 6 && lightId.suffix(6) == cleanSerial
            
            if idContainsSerial || nameContainsSerial || idEndsWithSerial {
                print("✅ Найдена лампа: \(light.metadata.name)")
                return true
            }
            
            return false
        }
    }

    /// Добавление НОВОЙ лампы по серийному номеру
    private func addNewLightBySerial(_ serialNumber: String) {
        print("🆕 Попытка добавить новую лампу: \(serialNumber)")
        
        // Используем современный API для добавления
        apiClient.addLightModern(serialNumber: serialNumber)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        print("❌ Ошибка добавления: \(error)")
                        
                        // Если лампа не найдена, показываем понятную ошибку
                        self?.error = HueAPIError.unknown(
                            "Лампа с серийным номером \(serialNumber) не найдена.\n\n" +
                            "Убедитесь что:\n" +
                            "• Лампа включена и находится рядом с мостом\n" +
                            "• Серийный номер введен правильно\n" +
                            "• Лампа совместима с Philips Hue"
                        )
                        self?.serialNumberFoundLights = []
                    }
                },
                receiveValue: { [weak self] foundLights in
                    guard let self = self else { return }
                    
                    if !foundLights.isEmpty {
                        print("✅ Найдено новых ламп: \(foundLights.count)")
                        self.serialNumberFoundLights = foundLights
                        
                        // Добавляем в общий список
                        let newLights = foundLights.filter { newLight in
                            !self.lights.contains { $0.id == newLight.id }
                        }
                        self.lights.append(contentsOf: newLights)
                        
                        // Показываем категории для первой лампы
                        if let firstLight = foundLights.first {
                            NavigationManager.shared.showCategoriesSelection(for: firstLight)
                        }
                    } else {
                        print("❌ Новые лампы не найдены")
                        self.error = HueAPIError.unknown("Лампа не найдена")
                        self.serialNumberFoundLights = []
                    }
                }
            )
            .store(in: &cancellables)
    }
 


    /// Fallback поиск по имени если API v1 недоступен
    private func searchByNameFallback(_ serialNumber: String) {
        // Ищем среди загруженных ламп по имени/метаданным  
        let foundLights = lights.filter { light in
            let lightName = light.metadata.name.lowercased()
            let serialLower = serialNumber.lowercased()
            
            // Проверяем содержится ли серийный номер в имени лампы
            return lightName.contains(serialLower) || 
                   light.metadata.name.uppercased().contains(serialNumber.uppercased())
        }
        
        if !foundLights.isEmpty {
            print("✅ Найдена лампа среди подключенных: \(foundLights.first?.metadata.name ?? "")")
            serialNumberFoundLights = foundLights
            isLoading = false
        } else {
            // Если не нашли по имени, показываем ошибку
            print("❌ Лампа с серийным номером \(serialNumber) не найдена")
            print("💡 Доступные серийные номера подключенных ламп:")
            
            // Показываем правильные серийные номера из uniqueid
            for light in lights {
                print("   📱 '\(light.metadata.name)' - возможные серийные номера из данных")
            }
            
            isLoading = false
            error = HueAPIError.unknown("Лампа с серийным номером \(serialNumber) не найдена среди подключенных устройств")
            serialNumberFoundLights = []
        }
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
    /// Валидирует серийный номер Philips Hue
    /// Принимает 6-символьные коды с буквами A-Z и цифрами 0-9
    func isValidSerialNumber(_ serialNumber: String) -> Bool {
        let cleanSerial = serialNumber
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
        
        // ИСПРАВЛЕНО: Принимаем любые буквы A-Z и цифры 0-9
        // Раньше было: "0123456789ABCDEFabcdef" (только HEX)
        // Теперь: полный алфавит + цифры
        let validCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        
        // Проверяем длину (6 символов) и допустимые символы
        let isValidLength = cleanSerial.count == 6
        let hasOnlyValidChars = cleanSerial.rangeOfCharacter(from: validCharacterSet.inverted) == nil
        
        if !isValidLength || !hasOnlyValidChars {
            print("❌ Серийный номер '\(serialNumber)' не прошел валидацию:")
            print("   Очищенный: '\(cleanSerial)'")
            print("   Длина: \(cleanSerial.count) (ожидается 6)")
            print("   Валидные символы: \(hasOnlyValidChars)")
            return false
        }
        
        print("✅ Серийный номер '\(cleanSerial)' валиден")
        return true
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
    
    /// Устанавливает состояние питания (вкл/выкл) явно
    /// - Parameters:
    ///   - light: Лампа
    ///   - on: Состояние питания
    func setPower(for light: Light, on: Bool) {
        let newState = LightState(
            on: OnState(on: on)
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
    
    /// Немедленно устанавливает яркость (для commit после жеста)
    /// - Parameters:
    ///   - light: Лампа
    ///   - brightness: 0-100
    func commitBrightness(for light: Light, brightness: Double) {
        brightnessUpdateWorkItem?.cancel()
        let newState = LightState(
            dimming: Dimming(brightness: brightness)
        )
        updateLight(light.id, state: newState, currentLight: light)
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
    
    /// Мигает лампой для визуального подтверждения (если лампа подключена и включена в сеть)
    /// - Parameter light: Лампа для мигания
    func blinkLight(_ light: Light) {
        apiClient.blinkLight(id: light.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Ошибка мигания лампы \(light.metadata.name): \(error)")
                    }
                },
                receiveValue: { success in
                    if success {
                        print("✅ Лампа \(light.metadata.name) мигнула успешно")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Запускает подписку на события (рекомендуемый подход)
    func startEventStream() {
        stopAutoRefresh() // Останавливаем старый метод
        
        eventStreamCancellable = apiClient.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleLightEvent(event)
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
    
    /// Обновляет статус связи конкретной лампы в памяти для мгновенного отклика UI
    /// - Parameters:
    ///   - lightId: ID лампы
    ///   - status: Новый статус связи
    func updateLightCommunicationStatus(lightId: String, status: CommunicationStatus) {
        guard let index = lights.firstIndex(where: { $0.id == lightId }) else {
            print("⚠️ LightsViewModel: Лампа с ID \(lightId) не найдена для обновления статуса")
            return
        }
        
        // Обновляем статус лампы в памяти
        lights[index].communicationStatus = status
        print("✅ LightsViewModel: Обновлен статус связи лампы \(lightId): \(status)")
        
        // Публикуем изменение для UI
        objectWillChange.send()
    }
    
    // MARK: - Private Methods
    
    /// Настраивает привязки данных
        private func setupBindings() {
            // Подписываемся на ошибки от API клиента
            apiClient.errorPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] error in
                    // ИСПРАВЛЕНИЕ: Игнорируем ошибки авторизации при первом запуске
                    if case HueAPIError.notAuthenticated = error {
                        print("📝 Требуется авторизация - ждем настройки подключения")
                    } else {
                        self?.error = error
                    }
                }
                .store(in: &cancellables)
            
            // ИСПРАВЛЕНИЕ: НЕ запускаем Event Stream автоматически
            // Он будет запущен после успешного подключения
        }
    
    /// Настраивает подписку на Event Stream для получения уведомлений об изменениях
    private func setupEventStreamSubscription() {
        print("🔄 Настраиваем подписку на Event Stream для реального времени...")
        
        apiClient.connectToEventStreamV2()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("❌ Ошибка Event Stream: \(error.localizedDescription)")
                    case .finished:
                        print("🔄 Event Stream завершен")
                    }
                },
                receiveValue: { [weak self] event in
                    print("📡 Получено событие от Event Stream: \(event)")
                    self?.handleLightEvent(event)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Обрабатывает события изменения состояния ламп
    private func handleLightEvent(_ event: HueEvent) {
        print("🔄 Обрабатываем событие лампы...")
        
        guard let eventData = event.data else {
            print("⚠️ Событие без данных")
            return
        }
        
        for data in eventData {
            print("📊 Тип события: \(String(describing: data.type)), ID: \(data.id ?? "unknown")")
            
            // Обрабатываем только события ламп
            if data.type == "light", let lightId = data.id {
                print("💡 Обновляем лампу с ID: \(lightId)")
                updateLightFromEvent(lightId: lightId, eventData: data)
            }
        }
    }
    
    /// Обновляет локальное состояние лампы на основе события
    private func updateLightFromEvent(lightId: String, eventData: EventData) {
        guard let index = lights.firstIndex(where: { $0.id == lightId }) else {
            print("⚠️ Лампа с ID \(lightId) не найдена в локальном списке")
            return
        }
        
        print("🔄 Обновляем лампу \(lights[index].metadata.name)...")
        
        var isUpdated = false
        
        // Обновляем состояние включения/выключения
        if let on = eventData.on {
            let currentOn = lights[index].on.on
            if currentOn != on.on {
                lights[index].on = on
                isUpdated = true
                print("   ⚡ Изменено состояние: \(on.on ? "включена" : "выключена")")
            }
        }
        
        // Обновляем яркость
        if let dimming = eventData.dimming {
            if lights[index].dimming?.brightness != dimming.brightness {
                lights[index].dimming = dimming
                isUpdated = true
                print("   🔆 Изменена яркость: \(dimming.brightness)%")
            }
        }
        
        // Обновляем цвет
        if let color = eventData.color {
            lights[index].color = color
            isUpdated = true
            print("   🎨 Изменен цвет")
        }
        
        // Обновляем цветовую температуру
        if let colorTemp = eventData.color_temperature {
            lights[index].color_temperature = colorTemp
            isUpdated = true
            print("   🌡️ Изменена цветовая температура")
        }
        
        // Принудительно обновляем статус reachable при любом событии
        if isUpdated {
            print("🔄 Обновляем статус reachable для лампы \(lightId)...")
            Task {
                await updateLightReachableStatus(lightId: lightId)
            }
        }
    }
    
    /// Обновляет статус reachable для конкретной лампы
    @MainActor
    private func updateLightReachableStatus(lightId: String) async {
        do {
            // Получаем актуальный статус из API v1
            let lightsV1 = try await apiClient.getLightsV1WithReachableStatus()
                .eraseToAnyPublisher()
                .asyncValue()
            
            // Находим соответствующую лампу в V1 API
            if let index = lights.firstIndex(where: { $0.id == lightId }),
               let lightV1 = apiClient.findMatchingV1Light(v2Light: lights[index], v1Lights: lightsV1) {
                
                let wasReachable = lights[index].isReachable
                let newReachable = lightV1.state?.reachable ?? false
                
                if wasReachable != newReachable {
                    lights[index].communicationStatus = newReachable ? .online : .offline
                    print("   📡 Обновлен статус reachable: \(newReachable ? "доступна" : "недоступна")")
                } else {
                    print("   📡 Статус reachable не изменился: \(newReachable ? "доступна" : "недоступна")")
                }
            }
        } catch {
            print("❌ Ошибка обновления статуса reachable: \(error.localizedDescription)")
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
        // Здесь должен быть расчет средней яркости включенных ламп
        0
    }
}



extension LightsViewModel {
    
    /// Правильный общий поиск новых ламп через Hue Bridge (v1 scan + сопоставление в v2)
    /// - Parameter completion: найденные новые лампы
    func searchForNewLights(completion: @escaping ([Light]) -> Void) {
        print("🔍 Поиск новых ламп (инициируем v1 scan)...")
        let currentLightIds = Set(lights.map { $0.id })
        
        apiClient.addLightModern(serialNumber: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        print("❌ Ошибка поиска: \(error)")
                        completion([])
                    }
                },
                receiveValue: { [weak self] allLights in
                    guard let self = self else { completion([]); return }
                    // Выделяем действительно новые по сравнению с текущим списком
                    let newLights = allLights.filter { !currentLightIds.contains($0.id) || $0.isNewLight }
                    print("✅ Найдено новых ламп: \(newLights.count)")
                    self.lights = allLights
                    completion(newLights)
                }
            )
            .store(in: &cancellables)
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




extension LightsViewModel {
    
   
    
    /// Обработка ошибок при поиске по серийному номеру
    private func handleSerialNumberError(_ error: Error, serialNumber: String) {
        if let hueError = error as? HueAPIError {
            switch hueError {
            case .notAuthenticated:
                self.error = HueAPIError.unknown(
                    "Требуется авторизация. Переподключитесь к мосту."
                )
                
            case .bridgeNotFound:
                self.error = HueAPIError.unknown(
                    "Мост Hue не найден в сети. Проверьте подключение."
                )
                
            case .networkError:
                self.error = HueAPIError.unknown(
                    "Ошибка сети. Проверьте подключение к той же Wi-Fi сети, что и мост."
                )
                
            case .httpError(let statusCode):
                if statusCode == 404 {
                    // Лампа не найдена - это нормальная ситуация
                    showNotFoundError(for: serialNumber)
                } else {
                    self.error = HueAPIError.unknown(
                        "Ошибка HTTP \(statusCode). Попробуйте позже."
                    )
                }
                
            default:
                self.error = hueError
            }
        } else {
            self.error = HueAPIError.unknown(
                "Неизвестная ошибка: \(error.localizedDescription)"
            )
        }
        
        serialNumberFoundLights = []
    }
    
    /// Показывает понятную ошибку когда лампа не найдена
    private func showNotFoundError(for serialNumber: String) {
        self.error = HueAPIError.unknown(
            """
            Лампа с серийным номером \(serialNumber) не найдена.
            
            Проверьте:
            • Лампа включена и находится в пределах 1 метра от моста
            • Серийный номер введен правильно (6 символов)
            • Лампа совместима с Philips Hue
            • Лампа не подключена к другому мосту
            
            Если лампа была подключена к другому мосту:
            1. Выключите и включите лампу 5 раз подряд
            2. Лампа мигнет, подтверждая сброс
            3. Попробуйте добавить снова
            """
        )
    }
    
 
    
    /// Автоматический поиск новых ламп в сети (без серийного номера)
    func searchForNewLights() {
        print("🔍 Автоматический поиск новых ламп...")
        
        isLoading = true
        error = nil
        
        // Сохраняем текущие ID для сравнения
        let currentLightIds = Set(lights.map { $0.id })
        
        // Просто обновляем список через API v2
        apiClient.getAllLights()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        print("❌ Ошибка поиска: \(error)")
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] allLights in
                    guard let self = self else { return }
                    
                    // Находим новые лампы
                    let newLights = allLights.filter { light in
                        !currentLightIds.contains(light.id) || light.isNewLight
                    }
                    
                    if !newLights.isEmpty {
                        print("✅ Найдено новых ламп: \(newLights.count)")
                        
                        self.lights = allLights
                        self.serialNumberFoundLights = newLights
                        
                        // Показываем UI для первой новой лампы
                        if let firstNewLight = newLights.first {
                            self.selectedLight = firstNewLight
                        }
                    } else {
                        print("ℹ️ Новые лампы не найдены")
                        self.error = HueAPIError.unknown(
                            """
                            Новые лампы не обнаружены.
                            
                            Убедитесь, что:
                            • Лампы подключены к питанию
                            • Лампы находятся рядом с мостом
                            • Лампы не подключены к другому мосту
                            """
                        )
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Сброс лампы (для подготовки к добавлению)
    func resetLightForAddition(completion: @escaping (Bool) -> Void) {
        print("💡 Инструкция по сбросу лампы:")
        print("1. Выключите лампу")
        print("2. Включите лампу на 3 секунды")
        print("3. Выключите на 3 секунды")
        print("4. Повторите шаги 2-3 еще 4 раза")
        print("5. Включите лампу - она должна мигнуть")
        print("6. Лампа готова к добавлению")
        
        // Показываем инструкцию пользователю
        self.error = HueAPIError.unknown(
            """
            Для сброса лампы:
            
            1. Выключите лампу
            2. Включите на 3 секунды
            3. Выключите на 3 секунды
            4. Повторите шаги 2-3 еще 4 раза
            5. Включите лампу - она мигнет
            
            После сброса попробуйте добавить лампу снова.
            """
        )
        
        completion(true)
    }
}


extension LightsViewModel {
    
    // MARK: - Dynamic Serial Number Mappings
    
    /// Ключ для UserDefaults
    private var mappingsKey: String { "HueLightSerialMappings" }
    
    /// Загружает сохраненные маппинги
    func loadSerialMappings() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mappingsKey) as? [String: String] ?? [:]
    }
    
    /// Сохраняет маппинг серийный номер -> ID лампы
    func saveSerialMapping(serial: String, lightId: String) {
        var mappings = loadSerialMappings()
        let cleanSerial = serial.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        mappings[cleanSerial] = lightId
        UserDefaults.standard.set(mappings, forKey: mappingsKey)
        
        print("💾 Сохранен маппинг: \(cleanSerial) -> \(lightId)")
    }
    
    /// Находит лампу по сохраненному маппингу
    func findLightByMapping(_ serial: String) -> Light? {
        let cleanSerial = serial.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        let mappings = loadSerialMappings()
        
        if let lightId = mappings[cleanSerial] {
            return lights.first { $0.id == lightId }
        }
        
        return nil
    }
    
    /// Очищает все сохраненные маппинги
    func clearSerialMappings() {
        UserDefaults.standard.removeObject(forKey: mappingsKey)
        print("🗑 Маппинги очищены")
    }
}

// MARK: - Combine to Async/Await Extensions

extension AnyPublisher {
    /// Преобразует Publisher в async/await
    func asyncValue() async throws -> Output {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}
