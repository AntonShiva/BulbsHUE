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
    // Простые экраны
    case environment
    case schedule
    case music
    
}

class NavigationManager: ObservableObject {
    @Published var currentRoute: Router = .environment
    
    static let shared = NavigationManager()
    private init() {}
    
    func go(_ route: Router) {
        currentRoute = route
    }
}
