//
//  RoomControlViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Room Control Color Managing Protocol

/// Протокол для управления цветами контрола комнаты
protocol RoomControlColorManaging {
    func updateRoomColor(roomId: String, sceneName: String) async
    func registerRoomControl(_ viewModel: RoomControlViewModel, for roomId: String) async
    func unregisterRoomControl(for roomId: String) async
}

// MARK: - Room Control View Model

/// ViewModel для управления отдельной комнатой
/// Аналогично ItemControlViewModel, но для комнат
@MainActor
final class RoomControlViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Текущая комната для управления
    @Published var currentRoom: RoomEntity?
    
    /// Состояние включения/выключения комнаты (всех ламп в ней)
    @Published var isOn: Bool = false
    
    /// Средняя яркость всех ламп в комнате
    @Published var brightness: Double = 100.0
    
    /// Запомненная яркость для восстановления при включении (аналогично лампам)
    private var rememberedBrightness: Double = 100.0
    
    /// Цвет комнаты по умолчанию (тот же что у ламп)
    @Published var defaultWarmColor = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    
    /// Динамический цвет комнаты на основе примененного пресета
    @Published var dynamicColor: Color = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
    
    // MARK: - Private Properties
    
    /// Сервис для управления лампами в комнате
    private var lightControlService: LightControlling?
    
    /// Сервис для управления комнатами
    private var roomService: RoomServiceProtocol?
    
    /// Репозиторий комнат для реактивных стримов
    private var roomRepository: RoomRepositoryProtocol?
    
    /// Менеджер цветов контрола
    private var colorManager: RoomControlColorManaging?
    
    /// Подписки Combine
    private var cancellables = Set<AnyCancellable>()
    
    /// Флаг конфигурации
    private var isConfigured: Bool = false
    
    /// Флаг для предотвращения циклических обновлений во время batch операций
    private var isUpdatingFromBatch: Bool = false
    
    /// Задача для дебаунса изменений яркости
    private var brightnessTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    private init() {
        // Пустая инициализация
    }
    
    /// Создать изолированный экземпляр (для SwiftUI StateObject)
    static func createIsolated() -> RoomControlViewModel {
        return RoomControlViewModel()
    }
    
    @MainActor
    deinit {
        // Отменяем все активные задачи при деинициализации
        brightnessTask?.cancel()
        cancellables.removeAll()
        
        // Отменяем регистрацию в цветовом сервисе
        if let currentRoom = currentRoom,
           let colorManager = colorManager as? RoomControlColorService {
            Task {
                await colorManager.unregisterRoomControl(for: currentRoom.id)
            }
        }
    }
    
    // MARK: - Configuration
    
    /// Конфигурирует ViewModel с сервисами и комнатой
    /// - Parameters:
    ///   - lightControlService: Сервис управления лампами
    ///   - roomService: Сервис управления комнатами
    ///   - roomRepository: Репозиторий для реактивных обновлений
    ///   - room: Комната для управления
    ///   - colorManager: Менеджер цветов контрола (опционально)
    func configure(
        with lightControlService: LightControlling,
        roomService: RoomServiceProtocol,
        room: RoomEntity,
        colorManager: RoomControlColorManaging? = nil
    ) {
        self.lightControlService = lightControlService
        self.roomService = roomService
        self.roomRepository = DIContainer.shared.roomRepository
        self.colorManager = colorManager ?? DIContainer.shared.roomControlColorService
        self.isConfigured = true
        setupObservers()
        setCurrentRoom(room)
        setupRoomObserver()
    }
    
    // MARK: - Public Methods
    
    /// Установить текущую комнату
    /// - Parameter room: Комната для управления
    func setCurrentRoom(_ room: RoomEntity) {
        self.currentRoom = room
        updateStateFromRoom()
        setupRoomObserver() // Переустанавливаем подписку на новую комнату
        
        // Обновляем динамический цвет из RoomColorStateService
        updateDynamicColor()
        
        // Регистрируемся в цветовом сервисе для получения обновлений
        if let colorManager = colorManager as? RoomControlColorService {
            Task {
                await colorManager.registerRoomControl(self, for: room.id)
            }
        }
    }
    
    /// Переключить питание всех ламп в комнате
    /// - Parameter newState: Новое состояние
    func setPower(_ newState: Bool) {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return }
        
        // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Предотвращаем обновления состояния во время batch операции
        isUpdatingFromBatch = true
        
        // ✅ СИНХРОНИЗАЦИЯ: Правильно синхронизируем isOn и brightness (как в лампах)
        if newState {
            // Включаем комнату - восстанавливаем запомненную яркость
            isOn = true
            let targetBrightness = rememberedBrightness > 0 ? rememberedBrightness : 100.0
            brightness = targetBrightness
        } else {
            // Выключаем комнату - запоминаем текущую яркость и сбрасываем слайдер в 0
            if brightness > 0 {
                rememberedBrightness = brightness
            }
            isOn = false
            brightness = 0.0 // ← КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: сбрасываем яркость в 0 при выключении
        }
        
        // Получаем все лампы комнаты
        let roomLights = getRoomLights()
        guard !roomLights.isEmpty else { 
            isUpdatingFromBatch = false
            return 
        }
        
        print("🏠 Переключение комнаты '\(room.name)' -> \(newState ? "ВКЛ" : "ВЫКЛ") (\(roomLights.count) ламп)")
        
        // Групповое управление лампами с ожиданием завершения
        Task { [weak self] in
            // Отправляем команды всем лампам ОДНОВРЕМЕННО, а не по очереди
            await withTaskGroup(of: Void.self) { group in
                for light in roomLights {
                    group.addTask {
                        lightControlService.setPower(for: light, on: newState)
                    }
                }
            }
            
            // Ждем небольшую задержку для получения обновлений от API
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            
            await MainActor.run { [weak self] in
                self?.isUpdatingFromBatch = false
                print("🏠 ✅ Batch операция завершена для комнаты '\(room.name)'")
            }
        }
    }
    
    /// Установить яркость всех ламп в комнате (с дебаунсом)
    /// - Parameter newBrightness: Новая яркость (0-100)
    func setBrightnessThrottled(_ newBrightness: Double) {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return }
        
        // УЛУЧШЕНИЕ: Предотвращаем конфликты при групповом изменении яркости
        isUpdatingFromBatch = true
        
        // Устанавливаем яркость локально для UI responsiveness
        brightness = newBrightness
        
        // ✅ СИНХРОНИЗАЦИЯ: Если яркость увеличивается при выключенной комнате - включаем комнату
        if newBrightness > 0 && !isOn {
            isOn = true
            rememberedBrightness = newBrightness
        }
        // ✅ СИНХРОНИЗАЦИЯ: Если яркость = 0 и комната включена - выключаем комнату
        else if newBrightness == 0 && isOn {
            if brightness > 0 {
                rememberedBrightness = brightness
            }
            isOn = false
        }
        // Обновляем запомненную яркость при изменении (если комната включена)
        else if newBrightness > 0 && isOn {
            rememberedBrightness = newBrightness
        }
        
        // Отменяем предыдущую задачу дебаунса
        brightnessTask?.cancel()
        
        // Создаем новую задачу с дебаунсом для плавности
        brightnessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды дебаунс
            
            guard let self = self, !Task.isCancelled else { return }
            
            let roomLights = self.getRoomLights()
            await withTaskGroup(of: Void.self) { group in
                for light in roomLights {
                    group.addTask {
                        lightControlService.setBrightness(for: light, brightness: newBrightness)
                    }
                }
            }
            
            await MainActor.run { [weak self] in
                self?.isUpdatingFromBatch = false
            }
        }
    }
    
    /// Зафиксировать яркость всех ламп в комнате
    /// - Parameter newBrightness: Финальная яркость
    func commitBrightness(_ newBrightness: Double) {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return }
        
        // Отменяем любую pending задачу
        brightnessTask?.cancel()
        isUpdatingFromBatch = true
        
        // Устанавливаем яркость локально
        brightness = newBrightness
        
        // ✅ СИНХРОНИЗАЦИЯ: Если яркость увеличивается при выключенной комнате - включаем комнату
        if newBrightness > 0 && !isOn {
            isOn = true
            rememberedBrightness = newBrightness
        }
        // ✅ СИНХРОНИЗАЦИЯ: Если яркость = 0 и комната включена - выключаем комнату
        else if newBrightness == 0 && isOn {
            if brightness > 0 {
                rememberedBrightness = brightness
            }
            isOn = false
        }
        // Обновляем запомненную яркость при изменении (если комната включена)
        else if newBrightness > 0 && isOn {
            rememberedBrightness = newBrightness
        }
        
        print("🏠 💡 Коммит яркости для комнаты '\(room.name)': \(newBrightness)%")
        
        // Групповой коммит яркости
        Task { [weak self] in
            let roomLights = self?.getRoomLights() ?? []
            await withTaskGroup(of: Void.self) { group in
                for light in roomLights {
                    group.addTask {
                        lightControlService.commitBrightness(for: light, brightness: newBrightness)
                    }
                }
            }
            
            // Небольшая задержка для синхронизации
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
            
            await MainActor.run { [weak self] in
                self?.isUpdatingFromBatch = false
                print("🏠 ✅ Коммит яркости завершен для комнаты '\(self?.currentRoom?.name ?? "Unknown")'")
            }
        }
    }
    
    /// Получить название комнаты
    func getRoomName() -> String {
        return currentRoom?.name ?? "Unknown Room"
    }
    
    /// Получить тип комнаты (родительская категория)
    func getRoomType() -> String {
        return currentRoom?.type.parentEnvironmentType.displayName.uppercased() ?? "ROOM"
    }
    
    /// Получить подтип комнаты (конкретное название)
    func getRoomSubtype() -> String {
        return currentRoom?.subtypeName ?? currentRoom?.type.displayName ?? "Room"
    }
    
    /// Получить иконку комнаты
    func getRoomIcon() -> String {
        return currentRoom?.iconName ?? "room"
    }
    
    /// Проверить доступность комнаты (есть ли доступные лампы)
    func isRoomAvailable() -> Bool {
        let roomLights = getRoomLights()
        return !roomLights.isEmpty && roomLights.contains { $0.isReachable }
    }
    
    /// Получить количество ламп в комнате
    func getLightCount() -> Int {
        return currentRoom?.lightCount ?? 0
    }
    
    // MARK: - Private Methods
    
    /// Настройка наблюдателей
    private func setupObservers() {
        guard let lightControlService = lightControlService else { return }
        
        // Подписываемся на изменения ламп
        lightControlService.lightsPublisher
            .sink { [weak self] lights in
                self?.updateStateFromLights(lights)
            }
            .store(in: &cancellables)
        
        // Подписываемся на изменения selectedRoomForMenu в NavigationManager
        NavigationManager.shared.$selectedRoomForMenu
            .sink { [weak self] updatedRoom in
                self?.handleNavigationManagerRoomUpdate(updatedRoom)
            }
            .store(in: &cancellables)
    }
    
    /// Обработка обновления комнаты из NavigationManager
    /// - Parameter updatedRoom: Обновленная комната из NavigationManager
    private func handleNavigationManagerRoomUpdate(_ updatedRoom: RoomEntity?) {
        guard let updatedRoom = updatedRoom,
              let currentRoom = currentRoom,
              currentRoom.id == updatedRoom.id else {
            return
        }
        
        // Обновляем текущую комнату с новыми данными
        self.currentRoom = updatedRoom
        print("✅ RoomControlViewModel: Обновлена комната из NavigationManager: \(updatedRoom.name)")
    }
    
    /// Настройка подписки на изменения конкретной комнаты
    private func setupRoomObserver() {
        guard let roomRepository = roomRepository, let roomId = currentRoom?.id else { return }
        
        // Подписываемся на изменения конкретной комнаты из репозитория
        roomRepository.roomStream(for: roomId)
            .sink { [weak self] updatedRoom in
                if let room = updatedRoom {
                    print("🏠 RoomControlViewModel: Получено обновление комнаты '\(room.name)' - тип: \(room.type.displayName), подтип: \(room.subtypeName)")
                    self?.currentRoom = room
                }
            }
            .store(in: &cancellables)
    }
    
    /// Обновить состояние комнаты на основе ламп
    /// - Parameter lights: Массив всех ламп
    private func updateStateFromLights(_ lights: [Light]) {
        guard let room = currentRoom else { return }
        
        // Игнорируем обновления от API во время batch операций
        guard !isUpdatingFromBatch else { 
            print("🏠 ⏸️ Пропускаем обновление состояния комнаты '\(room.name)' - выполняется batch операция")
            return 
        }
        
        let roomLights = lights.filter { room.lightIds.contains($0.id) }
        updateRoomState(from: roomLights)
    }
    
    /// Обновить состояние из текущей комнаты
    private func updateStateFromRoom() {
        let roomLights = getRoomLights()
        updateRoomState(from: roomLights)
    }
    
    /// Обновить состояние комнаты из массива ламп
    /// - Parameter roomLights: Лампы комнаты
    private func updateRoomState(from roomLights: [Light]) {
        if roomLights.isEmpty {
            isOn = false
            brightness = 0
            return
        }
        
        // Комната "включена" если хотя бы одна лампа включена
        let newIsOn = roomLights.contains { $0.on.on }
        
        // Средняя яркость включенных ламп
        let onLights = roomLights.filter { $0.on.on }
        let newBrightness: Double
        
        if !onLights.isEmpty {
            let totalBrightness = onLights.compactMap { $0.dimming?.brightness }.reduce(0, +)
            newBrightness = Double(totalBrightness) / Double(onLights.count)
        } else {
            newBrightness = 0
        }
        
        // ✅ СИНХРОНИЗАЦИЯ: Применяем ту же логику, что и в лампах
        if !newIsOn {
            // Комната выключена - показываем 0, но запоминаем яркость если она есть
            isOn = false
            brightness = 0.0
            if newBrightness > 0 {
                rememberedBrightness = newBrightness
            }
        } else {
            // Комната включена - показываем актуальную яркость и запоминаем её
            isOn = true
            let currentBrightness = newBrightness > 0 ? newBrightness : 1.0
            brightness = currentBrightness
            rememberedBrightness = currentBrightness
        }
    }
    
    /// Получить лампы комнаты
    /// - Returns: Массив ламп в комнате
    private func getRoomLights() -> [Light] {
        guard let room = currentRoom,
              let lightControlService = lightControlService else { return [] }
        
        return lightControlService.lights.filter { room.lightIds.contains($0.id) }
    }
    
    // MARK: - Color Management
    
    /// Получить текущий цвет контрола (динамический)
    var currentColor: Color {
        return dynamicColor
    }
    
    /// Обновить динамический цвет комнаты
    private func updateDynamicColor() {
        guard let room = currentRoom else { return }
        
        // Получаем цвет из RoomColorStateService (теперь с персистентным хранением)
        dynamicColor = RoomColorStateService.shared.getBaseColor(for: room)
        print("🎨 RoomControlViewModel: Обновлен динамический цвет для комнаты '\(room.name)'")
    }
    
    /// Обновить цвет комнаты на основе примененного пресета
    /// - Parameter sceneName: Имя сцены пресета
    func updateColorFromPreset(_ sceneName: String) {
        guard let room = currentRoom else { return }
        
        if let dominantColor = PresetColorsFactory.getDominantColor(for: sceneName) {
            // Сохраняем цвет в RoomColorStateService
            RoomColorStateService.shared.setRoomColor(room.id, color: dominantColor)
            // Обновляем локальный цвет
            dynamicColor = dominantColor
            print("🎨 RoomControlViewModel: Обновлен цвет комнаты '\(room.name)' из пресета '\(sceneName)'")
        } else {
            print("⚠️ RoomControlViewModel: Не найден доминирующий цвет для пресета '\(sceneName)'")
        }
    }
    
    /// Сбросить цвет комнаты к дефолтному
    func resetColor() {
        guard let room = currentRoom else { return }
        
        RoomColorStateService.shared.clearRoomState(room.id)
        dynamicColor = defaultWarmColor
        print("🎨 RoomControlViewModel: Сброшен цвет для комнаты '\(room.name)' к дефолтному")
    }
}

// MARK: - Room Service Protocol

/// Протокол для сервиса управления комнатами
protocol RoomServiceProtocol {
    func updateRoom(_ room: RoomEntity) async throws
    func deleteRoom(_ roomId: String) async throws
}

/// Реализация сервиса комнат
final class RoomService: RoomServiceProtocol {
    // TODO: Реализовать методы управления комнатами
    
    func updateRoom(_ room: RoomEntity) async throws {
        print("🏠 Обновление комнаты: \(room.name)")
    }
    
    func deleteRoom(_ roomId: String) async throws {
        print("🏠 Удаление комнаты: \(roomId)")
    }
}

// MARK: - Room Control Color Service

/// Сервис для управления цветами контролов комнат
actor RoomControlColorService: RoomControlColorManaging {
    /// Словарь активных RoomControlViewModel по ID комнат
    private var roomControlViewModels: [String: RoomControlViewModel] = [:]
    
    /// Регистрация RoomControlViewModel для получения обновлений цвета
    /// - Parameters:
    ///   - viewModel: ViewModel для регистрации
    ///   - roomId: ID комнаты
    func registerRoomControl(_ viewModel: RoomControlViewModel, for roomId: String) async {
        roomControlViewModels[roomId] = viewModel
    }
    
    /// Отмена регистрации RoomControlViewModel
    /// - Parameter roomId: ID комнаты
    func unregisterRoomControl(for roomId: String) async {
        roomControlViewModels.removeValue(forKey: roomId)
    }
    
    /// Обновить цвет контрола комнаты
    /// - Parameters:
    ///   - roomId: ID комнаты
    ///   - sceneName: Имя сцены пресета
    func updateRoomColor(roomId: String, sceneName: String) async {
        guard let viewModel = roomControlViewModels[roomId] else { return }
        await MainActor.run {
            viewModel.updateColorFromPreset(sceneName)
        }
    }
}
