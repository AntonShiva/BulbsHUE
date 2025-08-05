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
}

class NavigationManager: ObservableObject {
    @Published var currentRoute: Router = .environment
    
    // Переменная для отслеживания состояний в AddNewBulb
    @Published var isSearching: Bool = false
    @Published var showSelectCategories: Bool = false
    
    static let shared = NavigationManager()
    private init() {}
    
    // MARK: - Основная навигация между экранами
    func go(_ route: Router) {
        withAnimation(.easeInOut(duration: 0.15)) {
            currentRoute = route
            
            // Сбрасываем состояния поиска при переходе между основными экранами
            if route != .addNewBulb {
                isSearching = false
                showSelectCategories = false
            }
        }
    }
    
    // MARK: - Методы для управления состояниями AddNewBulb
    func startSearch() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isSearching = true
            showSelectCategories = false
        }
    }
    
    func showCategoriesSelection() {
        withAnimation(.easeInOut(duration: 0.15)) {
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
        }
    }
}
