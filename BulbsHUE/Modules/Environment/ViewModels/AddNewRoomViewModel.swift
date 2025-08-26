//
//  AddNewRoomViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI
import Combine

/// ViewModel для управления процессом создания новой комнаты
/// Следует принципам MVVM и SOLID, выделяя всю логику из View
@MainActor
final class AddNewRoomViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI State)
    
    /// Текущий шаг в процессе создания комнаты (0 - выбор категории, 1 - выбор ламп, 2 - ввод названия)
    @Published var currentStep: Int = 0
    
    /// Множество ID выбранных ламп
    @Published var selectedLights: Set<String> = []
    
    /// Пользовательское название комнаты
    @Published var customRoomName: String = ""
    
    /// Индикатор загрузки для создания комнаты
    @Published var isCreatingRoom: Bool = false
    
    /// Индикатор поиска новых ламп
    @Published var isSearchingLights: Bool = false
    
    // MARK: - Dependencies
    
    /// Менеджер категорий комнат для управления выбором типа
    let categoryManager: RoomCategoryManager
    
    /// Провайдер ламп для получения доступных устройств (устанавливается извне)
    private weak var lightsProvider: LightsProviding?
    
    /// Навигационный менеджер для управления переходами (устанавливается извне)
    private weak var navigationManager: NavigationManaging?
    
    /// Сервис создания комнат (устанавливается извне)
    private var roomCreationService: RoomCreationServicing?
    
    /// Сервис поиска ламп (устанавливается извне)
    private weak var lightsSearchProvider: LightsSearchProviding?
    
    // MARK: - Private Properties
    
    /// Набор cancellables для управления подписками Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Инициализация с минимальными зависимостями
    /// Другие зависимости устанавливаются через методы setup
    /// - Parameter categoryManager: Менеджер для управления категориями комнат
    init(categoryManager: RoomCategoryManager = RoomCategoryManager()) {
        self.categoryManager = categoryManager
        setupBindings()
    }
    
    // MARK: - Public Setup Methods
    
    /// Установка провайдера ламп
    /// - Parameter provider: Провайдер ламп
    func setLightsProvider(_ provider: LightsProviding) {
        self.lightsProvider = provider
    }
    
    /// Установка менеджера навигации
    /// - Parameter manager: Менеджер навигации
    func setNavigationManager(_ manager: NavigationManaging) {
        self.navigationManager = manager
    }
    
    /// Установка сервиса создания комнат
    /// - Parameter service: Сервис создания комнат
    func setRoomCreationService(_ service: RoomCreationServicing) {
        self.roomCreationService = service
    }
    
    /// Установка провайдера поиска ламп
    /// - Parameter provider: Провайдер поиска ламп
    func setLightsSearchProvider(_ provider: LightsSearchProviding) {
        self.lightsSearchProvider = provider
    }
    
    // MARK: - Private Setup
    
    /// Настройка привязок и подписок
    private func setupBindings() {
        // Отслеживаем изменения в выборе категории для автоматического обновления UI
        categoryManager.$selectedSubtype
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Триггерим обновление для hasSelection computed property
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    /// Проверяет, должна ли кнопка продолжения быть активной
    var isContinueButtonEnabled: Bool {
        switch currentStep {
        case 0:
            // На первом шаге кнопка активна только если выбрана категория
            return categoryManager.hasSelection
        case 1:
            // На втором шаге кнопка активна только если выбраны лампы и не идет поиск
            return !selectedLights.isEmpty && !isSearchingLights
        case 2:
            // На третьем шаге кнопка активна только если введено название комнаты и не создается комната
            return !customRoomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreatingRoom
        default:
            return false
        }
    }
    
    /// Текст для кнопки в зависимости от текущего шага
    var continueButtonText: String {
        switch currentStep {
        case 0:
            return "continue"
        case 1:
            return isSearchingLights ? "searching..." : "continue"
        case 2:
            return isCreatingRoom ? "creating..." : "create"
        default:
            return "continue"
        }
    }
    
    /// Список доступных ламп, преобразованных в LightEntity
    /// ✅ ВСЕ ЛАМПЫ (включая отключенные) для создания комнат
    var availableLights: [LightEntity] {
        guard let lightsProvider = lightsProvider else { return [] }
        
        return lightsProvider.lights
            .compactMap { light in
                // ✅ ПРАВИЛЬНАЯ ЛОГИКА: используем пользовательские подтипы, НЕ архетипы API
                // Если лампа имеет пользовательский подтип - используем его
                let lightType: LightType
                let lightSubtype: LightSubtype?
                
                if let userSubtypeName = light.metadata.userSubtypeName {
                    // Лампа уже настроена пользователем - используем его выбор
                    lightSubtype = LightSubtype.allCases.first { $0.displayName.uppercased() == userSubtypeName.uppercased() }
                    lightType = lightSubtype?.parentType ?? .other
                } else {
                    // Лампа еще не настроена - используем общий тип "other" до настройки
                    lightType = .other
                    lightSubtype = nil
                }
                
                return LightEntity(
                    id: light.id,
                    name: light.metadata.name,
                    type: lightType,
                    subtype: lightSubtype,
                    isOn: light.on.on,
                    brightness: Double(light.dimming?.brightness ?? 0),
                    color: light.color?.xy.map { LightColor(x: $0.x, y: $0.y) },
                    colorTemperature: light.color_temperature?.mirek,
                    isReachable: light.isReachable, // Показываем реальный статус лампы
                    roomId: nil, // Лампы доступны для назначения в комнату
                    userSubtype: light.metadata.userSubtypeName,
                    userIcon: light.metadata.userSubtypeIcon
                )
            }
    }
    
    // MARK: - Public Actions (View Event Handlers)
    
    /// Обработка нажатия на кнопку продолжения/создания
    func handleContinueAction() {
        switch currentStep {
        case 0:
            // Переход к выбору ламп
            proceedToLightSelection()
        case 1:
            // Переход к вводу названия комнаты
            proceedToNameInput()
        case 2:
            // Создание комнаты
            Task {
                await createRoom()
            }
        default:
            break
        }
    }
    
    /// Переключение выбора лампы
    /// - Parameter lightId: ID лампы для переключения выбора
    func toggleLightSelection(_ lightId: String) {
        if selectedLights.contains(lightId) {
            selectedLights.remove(lightId)
        } else {
            selectedLights.insert(lightId)
        }
    }
    
    /// Проверка, выбрана ли конкретная лампа
    /// - Parameter lightId: ID лампы для проверки
    /// - Returns: true если лампа выбрана
    func isLightSelected(_ lightId: String) -> Bool {
        return selectedLights.contains(lightId)
    }
    
    /// Возврат к предыдущему шагу
    func goToPreviousStep() {
        guard currentStep > 0 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep -= 1
        }
    }
    
    /// Отмена процесса создания комнаты
    func cancelRoomCreation() {
        // Сброс состояния
        currentStep = 0
        selectedLights.removeAll()
        categoryManager.clearSelection()
        
        // Навигация назад
        navigationManager?.go(Router.environment)
    }
    

    
    // MARK: - Private Methods
    
    /// Переход к шагу выбора ламп
    private func proceedToLightSelection() {
        guard categoryManager.hasSelection else {
            print("❌ Попытка перехода без выбранной категории")
            return
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = 1
        }
        
        // ✅ АВТОМАТИЧЕСКИЙ ПОИСК ЛАМП при переходе к выбору
        print("🔍 Запускаем автоматический поиск ламп при создании комнаты...")
        Task {
            await performLightSearch()
        }
    }
    
    /// Переход к шагу ввода названия комнаты
    private func proceedToNameInput() {
        guard !selectedLights.isEmpty else {
            print("❌ Попытка перехода без выбранных ламп")
            return
        }
        
        // Устанавливаем название по умолчанию из выбранного подтипа
        if let selectedSubtype = categoryManager.getSelectedSubtype() {
            customRoomName = selectedSubtype.name
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = 2
        }
    }
    
    /// Создание комнаты с выбранными лампами
    private func createRoom() async {
        guard let selectedSubtype = categoryManager.getSelectedSubtype(),
              let roomCreationService = roomCreationService,
              !selectedLights.isEmpty else {
            print("❌ Недостаточно данных для создания комнаты")
            isCreatingRoom = false
            return
        }
        
        isCreatingRoom = true
        
        do {
            // Получаем выбранные лампы
            let selectedLightEntities = availableLights.filter { selectedLights.contains($0.id) }
            let selectedLightIds = selectedLightEntities.map { $0.id }
            
            print("🏠 Начинаем создание комнаты:")
            print("   Название: '\(selectedSubtype.name)'")
            print("   Тип: '\(selectedSubtype.roomType)'")
            print("   Иконка: '\(selectedSubtype.iconName)'")
            print("   Лампы: \(selectedLightEntities.map { $0.name })")
            
            // ✅ РЕАЛЬНАЯ ЛОГИКА: Создаем комнату через Use Case
            let finalRoomName = customRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Если пользователь не ввел название - используем название подтипа
            let roomName = finalRoomName.isEmpty ? selectedSubtype.name : finalRoomName
            
            print("📝 Используем название комнаты: '\(roomName)' (пользовательское: '\(finalRoomName)', подтип: '\(selectedSubtype.name)')")
            
            let roomEntity = try await roomCreationService.createRoomWithLights(
                name: roomName,
                type: selectedSubtype.roomType,
                subtypeName: selectedSubtype.name, // ✅ Передаем название подтипа (DOWNSTAIRS)
                iconName: selectedSubtype.iconName, // ✅ Передаем иконку подтипа
                lightIds: selectedLightIds
            )
            
            print("✅ Комната успешно создана:")
            print("   ID: \(roomEntity.id)")
            print("   Название: \(roomEntity.name)")
            print("   Тип: \(roomEntity.type)")
            print("   Количество ламп: \(roomEntity.lightCount)")
            
            // После успешного создания возвращаемся к основному экрану
            await MainActor.run {
                navigationManager?.go(Router.environment)
                resetState()
            }
            
        } catch {
            print("❌ Ошибка создания комнаты: \(error.localizedDescription)")
            // TODO: Показать алерт пользователю об ошибке
        }
        
        await MainActor.run {
            isCreatingRoom = false
        }
    }
    
    /// Сброс состояния ViewModel
    private func resetState() {
        currentStep = 0
        selectedLights.removeAll()
        customRoomName = ""
        categoryManager.clearSelection()
        isCreatingRoom = false
        isSearchingLights = false
    }
    
    /// Выполняет поиск новых ламп
    @MainActor
    private func performLightSearch() async {
        guard let lightsSearchProvider = lightsSearchProvider else {
            print("❌ LightsSearchProvider не установлен")
            return
        }
        
        isSearchingLights = true
        
        print("🔍 Начинаем поиск новых ламп для создания комнаты...")
        
        // Используем async/await версию поиска ламп
        let foundLights = await withCheckedContinuation { continuation in
            lightsSearchProvider.searchForNewLights { lights in
                continuation.resume(returning: lights)
            }
        }
        
        if foundLights.isEmpty {
            print("ℹ️ Новых ламп не найдено")
        } else {
            print("✅ Найдено \(foundLights.count) новых ламп")
        }
        
        // UI обновится автоматически через lightsProvider.lights
        
        isSearchingLights = false
    }
    

}

// MARK: - Protocol Definitions

/// Протокол для провайдера ламп (Dependency Inversion Principle)
protocol LightsProviding: AnyObject {
    var lights: [Light] { get }
}

/// Протокол для поиска ламп (Dependency Inversion Principle)
protocol LightsSearchProviding: AnyObject {
    func searchForNewLights(completion: @escaping ([Light]) -> Void)
}

/// Протокол для менеджера навигации (Dependency Inversion Principle)
protocol NavigationManaging: AnyObject {
    func go(_ destination: Router)
}

/// Протокол для сервиса создания комнат (Dependency Inversion Principle)
protocol RoomCreationServicing {
    func createRoomWithLights(name: String, type: RoomSubType, subtypeName: String, iconName: String, lightIds: [String]) async throws -> RoomEntity
}

// MARK: - Extensions для соответствия протоколам

/// Расширение AppViewModel для соответствия LightsProviding
extension AppViewModel: LightsProviding {
    var lights: [Light] {
        return lightsViewModel.lights
    }
}

/// Расширение LightsViewModel для соответствия LightsSearchProviding
extension LightsViewModel: LightsSearchProviding {
    // Метод уже реализован в LightsViewModel+NetworkSearch.swift
}

/// Расширение NavigationManager для соответствия NavigationManaging
extension NavigationManager: NavigationManaging {
    // Уже реализует метод go(_:)
}

// MARK: - Room Creation Service Implementation

/// Реализация сервиса создания комнат через DIContainer
class DIRoomCreationService: RoomCreationServicing {
    private let createRoomWithLightsUseCase: CreateRoomWithLightsUseCase
    
    init(createRoomWithLightsUseCase: CreateRoomWithLightsUseCase) {
        self.createRoomWithLightsUseCase = createRoomWithLightsUseCase
    }
    
    func createRoomWithLights(name: String, type: RoomSubType, subtypeName: String, iconName: String, lightIds: [String]) async throws -> RoomEntity {
        let input = CreateRoomWithLightsUseCase.Input(
            roomName: name,
            roomType: type,
            subtypeName: subtypeName,
            iconName: iconName,
            lightIds: lightIds
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            createRoomWithLightsUseCase.execute(input)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { roomEntity in
                        continuation.resume(returning: roomEntity)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
}
