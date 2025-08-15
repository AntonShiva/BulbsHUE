//
//  AppStore.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Redux Store
/// Основной Store приложения
/// Управляет глобальным состоянием и обработкой действий
@MainActor
final class AppStore: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var state: AppState
    
    // MARK: - Private Properties
    private let middlewares: [Middleware]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        initialState: AppState = AppState(),
        middlewares: [Middleware] = []
    ) {
        self.state = initialState
        self.middlewares = middlewares
    }
    
    // MARK: - Public Methods
    
    /// Отправить действие в Store
    func dispatch(_ action: AppAction) {
        let oldState = state
        
        // Применяем middleware
        let processedAction = middlewares.reduce(action) { currentAction, middleware in
            return middleware.process(action: currentAction, state: oldState, store: self)
        }
        
        // Применяем редьюсер
        state = appReducer(state: oldState, action: processedAction)
        
        // Логируем изменения в debug режиме
        #if DEBUG
        logStateChange(from: oldState, to: state, action: processedAction)
        #endif
    }
    
    // MARK: - Selectors (Computed Properties)
    
    /// Лампы в Environment
    var environmentLights: [LightEntity] {
        state.lights.assignedLights
    }
    
    /// Доступные для добавления лампы
    var availableLights: [LightEntity] {
        state.lights.availableLights
    }
    
    /// Состояние подключения к мосту
    var connectionStatus: ConnectionStatus {
        state.bridge.connectionStatus
    }
    
    /// Статус загрузки ламп
    var isLightsLoading: Bool {
        state.lights.isLoading
    }
    
    /// Ошибка ламп
    var lightsError: String? {
        state.lights.error
    }
    
    // MARK: - Private Methods
    
    private func logStateChange(from oldState: AppState, to newState: AppState, action: AppAction) {
        if oldState != newState {
            print("🔄 Redux: \(action)")
            
            // Логируем только измененные части состояния
            if oldState.lights != newState.lights {
                print("   💡 Lights: \(newState.lights.assignedLights.count) assigned, \(newState.lights.allLights.count) total")
            }
            
            if oldState.bridge != newState.bridge {
                print("   🌉 Bridge: \(newState.bridge.connectionStatus)")
            }
            
            if oldState.scenes != newState.scenes {
                print("   � Scenes: \(newState.scenes.scenes.count) loaded")
            }
        }
    }
}

// MARK: - Middleware Protocol
protocol Middleware {
    func process(action: AppAction, state: AppState, store: AppStore) -> AppAction
}

// MARK: - Redux Store Extensions для удобства
extension AppStore {
    
    /// Подписаться на изменения определенной части состояния
    func subscribe<T: Equatable>(
        to keyPath: KeyPath<AppState, T>
    ) -> AnyPublisher<T, Never> {
        return $state
            .map { $0[keyPath: keyPath] }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Получить текущее значение по KeyPath
    func getValue<T>(for keyPath: KeyPath<AppState, T>) -> T {
        return state[keyPath: keyPath]
    }
}
