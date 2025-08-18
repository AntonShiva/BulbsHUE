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
    
    // Тип поиска ламп
    @Published var searchType: SearchType = .network
    
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
            print("📂 Показываем выбор категории для лампы: \(light.metadata.name)")
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
        }
    }
    
    // MARK: - Методы для управления MenuView
    func showMenuView(for light: Light) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedLightForMenu = light
            currentRoute = .menuView
            togleTabBarVisible() // Обновляем видимость TabBar
            print("📱 Показываем MenuView для лампы: \(light.metadata.name)")
        }
    }
    
    func hideMenuView() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedLightForMenu = nil
            currentRoute = .environment
            togleTabBarVisible() // Обновляем видимость TabBar
            print("📱 Скрываем MenuView")
        }
    }
}
