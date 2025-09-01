//
//  NavigationManager.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI
import Combine


// MARK: - Navigation Route
// ВСЕ возможные состояния экранов
enum Router: Equatable {
    // Основные экраны (для TabBar)
    case environment
    
    case schedule
    case music
    
    // Экраны добавления лампочек
    case addNewBulb               // Экран добавления новой лампочки
    case searchResults            // Поиск лампочек в сети + результаты
    case selectCategories         // Выбор категории для лампочки
    
    // Меню настроек лампы
    case menuView                 // Меню настроек конкретной лампы
    
    // Environment Bulbs
    case environmentBulbs         // Экран выбора окружающих сцен освещения
    case presetColorEdit          // Экран редактирования пресета сцены
    
    // Development
    case development              // Development dashboard
    case migrationDashboard       // Migration progress dashboard
    
    case addRoom
}

enum EnvironmentTab {
    case bulbs, rooms
}

class NavigationManager: ObservableObject {
    @Published var currentRoute: Router = .environment
    @Published var еnvironmentTab: EnvironmentTab = .bulbs
    
    // Переменная для отслеживания состояний в AddNewBulb
    @Published var isSearching: Bool = false
    @Published var showSelectCategories: Bool = false
    /// Флаг показа TabBar
    @Published var isTabBarVisible: Bool = true
    
    // Выбранная лампа для настройки категории
    @Published var selectedLight: Light? = nil
    
    // Выбранная лампа для показа MenuView
    @Published var selectedLightForMenu: Light? = nil
    
    // Выбранная комната для показа MenuView
    @Published var selectedRoomForMenu: RoomEntity? = nil
    
    // Выбранная сцена для редактирования в PresetColorView
    @Published var selectedSceneForEdit: EnvironmentSceneEntity? = nil
    
    // Тип поиска ламп
    @Published var searchType: SearchType = .network
    
    // Введенный серийный номер
    @Published var enteredSerialNumber: String? = nil
    
    enum SearchType {
        case network        // Автоматический поиск в сети
        case serialNumber   // Поиск по серийному номеру
    }
    
    /// Проверка, находимся ли мы на главном экране вкладки
   func togleTabBarVisible() {
      isTabBarVisible = currentRoute == .environment || currentRoute == .schedule || currentRoute == .music
       }
    
    static let shared = NavigationManager()
    
    // Ссылка на DataPersistenceService для сохранения данных
    weak var dataPersistenceService: DataPersistenceService?
    
    private init() {}
    
    // MARK: - Основная навигация между экранами
    func go(_ route: Router) {
        withAnimation(.easeInOut(duration: 0.15)) {
            currentRoute = route
            
            // Сбрасываем состояния поиска при переходе между основными экранами
            if route != .addNewBulb {
                isSearching = false
                showSelectCategories = false
                selectedLight = nil
            }
            
            // Обновляем видимость TabBar
            togleTabBarVisible()
        }
    }
    
    /// Возврат на предыдущий экран
    func back() {
        withAnimation(.easeInOut(duration: 0.15)) {
            // Логика возврата в зависимости от текущего маршрута
            switch currentRoute {
            case .addNewBulb, .searchResults, .selectCategories:
                currentRoute = .environment
            case .environmentBulbs:
                currentRoute = .environment
            case .presetColorEdit:
                currentRoute = .environmentBulbs
            case .menuView:
                currentRoute = .environment
            case .development, .migrationDashboard:
                currentRoute = .environment
            default:
                currentRoute = .environment
            }
            
            // Сбрасываем состояния
            resetAddBulbState()
            selectedLightForMenu = nil
            selectedRoomForMenu = nil
            selectedSceneForEdit = nil
            
            // Обновляем видимость TabBar
            togleTabBarVisible()
        }
    }
    
    // MARK: - Методы для управления состояниями AddNewBulb
    func startSearch() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isSearching = true
            showSelectCategories = false
            searchType = .network
        }
    }
    
 
    /// Запуск поиска по серийному номеру с показом результатов
    func startSerialNumberSearch() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isSearching = true
            showSelectCategories = false
            searchType = .serialNumber
          
        }
    }
    
    func showCategoriesSelection(for light: Light) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedLight = light
            showSelectCategories = true
        }
    }
    
    func hideCategoriesSelection() {
        withAnimation(.easeInOut(duration: 0.15)) {
            showSelectCategories = false
        }
    }
    
    func resetAddBulbState() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isSearching = false
            showSelectCategories = false
            selectedLight = nil
            searchType = .network
            enteredSerialNumber = nil
        }
    }
    
    // MARK: - Методы для управления MenuView
    func showMenuView(for light: Light) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedLightForMenu = light
            selectedRoomForMenu = nil // Сбрасываем выбор комнаты
            currentRoute = .menuView
            togleTabBarVisible() // Обновляем видимость TabBar
        }
    }
    
    func showMenuView(for room: RoomEntity) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedRoomForMenu = room
            selectedLightForMenu = nil // Сбрасываем выбор лампы
            currentRoute = .menuView
            togleTabBarVisible() // Обновляем видимость TabBar
        }
    }
    
    func hideMenuView() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedLightForMenu = nil
            selectedRoomForMenu = nil
            currentRoute = .environment
            togleTabBarVisible() // Обновляем видимость TabBar
        }
    }
    
    // MARK: - Методы для управления PresetColorView
    
    /// Показать экран редактирования пресета сцены
    func showPresetColorEdit(for scene: EnvironmentSceneEntity) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedSceneForEdit = scene
            currentRoute = .presetColorEdit
            togleTabBarVisible() // Обновляем видимость TabBar
        }
    }
    
    /// Скрыть экран редактирования пресета
    func hidePresetColorEdit() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedSceneForEdit = nil
            currentRoute = .environmentBulbs
            togleTabBarVisible() // Обновляем видимость TabBar
        }
    }
    
    // MARK: - Методы для обновления имен (вместо NotificationCenter)
    
    /// Обновляет имя лампы в selectedLightForMenu и уведомляет всех подписчиков
    func updateLightName(lightId: String, newName: String) {
        // Обновляем selectedLightForMenu если это нужная лампа
        if let currentLight = selectedLightForMenu, currentLight.id == lightId {
            var updatedLight = currentLight
            updatedLight.metadata.name = newName
            selectedLightForMenu = updatedLight
        }
        
        // Обновляем AppViewModel.lightsViewModel для синхронизации везде
        if let appViewModel = dataPersistenceService?.appViewModel {
            if let index = appViewModel.lightsViewModel.lights.firstIndex(where: { $0.id == lightId }) {
                appViewModel.lightsViewModel.lights[index].metadata.name = newName
            }
            
            // Используем встроенный метод если есть
            if let light = appViewModel.lightsViewModel.lights.first(where: { $0.id == lightId }) {
                appViewModel.lightsViewModel.renameLight(light, newName: newName)
            }
        }
    }
    
    /// Обновляет имя комнаты в selectedRoomForMenu и уведомляет всех подписчиков  
    func updateRoomName(roomId: String, newName: String) {
        // Обновляем selectedRoomForMenu если это нужная комната
        if let currentRoom = selectedRoomForMenu, currentRoom.id == roomId {
            let updatedRoom = RoomEntity(
                id: currentRoom.id,
                name: newName,
                type: currentRoom.type,
                subtypeName: currentRoom.subtypeName,
                iconName: currentRoom.iconName,
                lightIds: currentRoom.lightIds,
                isActive: currentRoom.isActive,
                createdAt: currentRoom.createdAt,
                updatedAt: Date()
            )
            selectedRoomForMenu = updatedRoom
        }
    }
}
