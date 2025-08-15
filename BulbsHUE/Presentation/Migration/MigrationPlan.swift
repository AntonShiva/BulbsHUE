//
//  MigrationPlan.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

/**
 # Пошаговый план безопасной миграции
 
 ## Принцип "Strangler Fig Pattern"
 Постепенное замещение старого кода новым без нарушения работоспособности.
 
 ## Этапы миграции:
 
 ### 🟡 ЭТАП 1: Подготовка (ВЫПОЛНЕНО)
 - [x] Clean Architecture структура
 - [x] Redux Store и базовые экшены
 - [x] Удаление дублирования NavigationAction
 
 ### 🔵 ЭТАП 2: Инфраструктура совместимости (ТЕКУЩИЙ)
 - [x] MigrationAdapter для постепенного перехода
 - [ ] Feature flags для управления миграцией
 - [ ] Конверторы между старыми и новыми моделями
 - [ ] Интеграция MigrationAdapter в основные компоненты
 
 ### 🟢 ЭТАП 3: Bridge Service (1-2 недели)
 Самая критичная, но изолированная часть
 
 #### Неделя 1: Подготовка Bridge миграции
 - [ ] Реализовать BridgeRepository
 - [ ] Создать UseCases для подключения к мосту
 - [ ] Тестировать параллельную работу старой/новой системы
 
 #### Неделя 2: Переключение Bridge
 - [ ] Включить MigrationFeatureFlags.useNewBridgeArchitecture = true
 - [ ] Убедиться что все функции работают
 - [ ] Удалить старый Bridge код
 
 ### 🟠 ЭТАП 4: Light Management (2 недели)
 Управление лампами - основная функциональность
 
 #### Неделя 3: Подготовка Light миграции
 - [ ] Доработать LightRepository
 - [ ] Создать все Light UseCases
 - [ ] Реализовать конверторы Light <-> LightEntity
 
 #### Неделя 4: Переключение Lights
 - [ ] Включить MigrationFeatureFlags.useReduxForLights = true
 - [ ] Тестировать UI компоненты
 - [ ] Проверить сохранение состояния
 
 ### 🟣 ЭТАП 5: Scenes & Groups (1 неделя)
 #### Неделя 5: Сцены и группы
 - [ ] Мигрировать ScenesViewModel → Redux
 - [ ] Мигрировать GroupsViewModel → Redux
 - [ ] Обновить UI компоненты
 
 ### 🔴 ЭТАП 6: Остальные модули (1 неделя)
 #### Неделя 6: Sensors, Rules, etc.
 - [ ] Мигрировать RulesViewModel → Redux
 - [ ] Мигрировать SensorsViewModel → Redux
 - [ ] Финальная очистка
 
 ### ⚪ ЭТАП 7: Cleanup (1 неделя)
 #### Неделя 7: Очистка и оптимизация
 - [ ] Удалить MigrationAdapter
 - [ ] Удалить старые ViewModels
 - [ ] Убрать feature flags
 - [ ] Финальное тестирование
 */

/// Детальные инструкции для каждого этапа
enum MigrationStep: CaseIterable, Identifiable {
    case preparation
    case compatibility
    case bridgeService
    case lightManagement
    case scenesAndGroups
    case remainingModules
    case cleanup
    
    var id: String { return self.title }
    
    var title: String {
        switch self {
        case .preparation: return "Подготовка архитектуры"
        case .compatibility: return "Совместимость старой/новой системы"
        case .bridgeService: return "Миграция Bridge Service"
        case .lightManagement: return "Миграция Light Management"
        case .scenesAndGroups: return "Миграция Scenes & Groups"
        case .remainingModules: return "Миграция остальных модулей"
        case .cleanup: return "Очистка и оптимизация"
        }
    }
    
    var description: String {
        switch self {
        case .preparation:
            return """
            ✅ ВЫПОЛНЕНО
            - Clean Architecture структура создана
            - Redux Store настроен
            - NavigationAction удален из Redux
            """
            
        case .compatibility:
            return """
            🔵 ТЕКУЩИЙ ЭТАП
            - Создать MigrationAdapter для безопасного перехода
            - Настроить feature flags
            - Реализовать конверторы моделей
            - Интегрировать в основные компоненты
            
            Цель: Обеспечить работу старой и новой системы параллельно
            """
            
        case .bridgeService:
            return """
            🟢 СЛЕДУЮЩИЙ ЭТАП (1-2 недели)
            - Реализовать полный BridgeRepository
            - Создать UseCases для работы с мостом
            - Тестировать подключение через новую архитектуру
            - Постепенно переключать на новую систему
            
            Критично: Bridge - основа всего приложения
            """
            
        case .lightManagement:
            return """
            🟠 ЭТАП 4 (2 недели)
            - Доработать LightRepository и UseCases
            - Мигрировать управление лампами на Redux
            - Обновить все UI компоненты для работы с новым состоянием
            - Тестировать сохранение пользовательских настроек
            
            Важно: Не потерять пользовательские категории и настройки ламп
            """
            
        case .scenesAndGroups:
            return """
            🟣 ЭТАП 5 (1 неделя)
            - Мигрировать ScenesViewModel на Redux
            - Мигрировать GroupsViewModel на Redux
            - Обновить соответствующие UI компоненты
            
            Относительно простой этап, так как основа уже готова
            """
            
        case .remainingModules:
            return """
            🔴 ЭТАП 6 (1 неделя)
            - Мигрировать RulesViewModel
            - Мигрировать SensorsViewModel
            - Перевести оставшиеся модули на новую архитектуру
            
            Завершающий этап функциональной миграции
            """
            
        case .cleanup:
            return """
            ⚪ ЭТАП 7 (1 неделя)
            - Удалить MigrationAdapter
            - Удалить старые ViewModels
            - Убрать feature flags
            - Финальная оптимизация кода
            - Полное тестирование
            
            Результат: Чистая Clean Architecture + Redux система
            """
        }
    }
    
    var risks: [String] {
        switch self {
        case .preparation:
            return ["Конфликты именования", "Неправильная структура папок"]
            
        case .compatibility:
            return [
                "Дублирование состояния",
                "Рассинхронизация старой и новой системы",
                "Неправильная конвертация моделей"
            ]
            
        case .bridgeService:
            return [
                "Потеря подключения к мосту",
                "Проблемы с авторизацией",
                "Конфликты в состоянии подключения"
            ]
            
        case .lightManagement:
            return [
                "Потеря пользовательских настроек ламп",
                "Проблемы с синхронизацией состояния",
                "Падение производительности UI"
            ]
            
        case .scenesAndGroups:
            return [
                "Проблемы с активацией сцен",
                "Некорректная группировка ламп"
            ]
            
        case .remainingModules:
            return [
                "Поломка автоматизации (Rules)",
                "Проблемы с датчиками"
            ]
            
        case .cleanup:
            return [
                "Остаточные ссылки на старый код",
                "Регрессии после удаления MigrationAdapter"
            ]
        }
    }
    
    var successCriteria: [String] {
        switch self {
        case .preparation:
            return [
                "Проект собирается без ошибок",
                "Все тесты проходят",
                "Redux Store инициализируется корректно"
            ]
            
        case .compatibility:
            return [
                "MigrationAdapter корректно переключает между системами",
                "Feature flags работают",
                "Конверторы моделей не теряют данные"
            ]
            
        case .bridgeService:
            return [
                "Подключение к мосту работает через новую архитектуру",
                "Авторизация сохраняется",
                "Старая система может быть отключена без потери функциональности"
            ]
            
        case .lightManagement:
            return [
                "Все операции с лампами работают через Redux",
                "UI обновляется корректно",
                "Пользовательские настройки сохраняются"
            ]
            
        case .scenesAndGroups:
            return [
                "Сцены активируются корректно",
                "Группы работают",
                "UI отображает актуальное состояние"
            ]
            
        case .remainingModules:
            return [
                "Все ViewModels мигрированы",
                "Автоматизация работает",
                "Датчики отображаются корректно"
            ]
            
        case .cleanup:
            return [
                "Проект содержит только новый код",
                "Нет мертвого кода",
                "Производительность не ухудшилась",
                "Все тесты проходят"
            ]
        }
    }
}

/// Текущий статус миграции
class MigrationStatus: ObservableObject {
    @Published var currentStep: MigrationStep = .compatibility
    @Published var completedSteps: Set<MigrationStep> = [.preparation]
    
    func markCompleted(_ step: MigrationStep) {
        completedSteps.insert(step)
        
        // Автоматически переходим к следующему этапу
        if let nextIndex = MigrationStep.allCases.firstIndex(of: step).map({ $0 + 1 }),
           nextIndex < MigrationStep.allCases.count {
            currentStep = MigrationStep.allCases[nextIndex]
        }
    }
    
    func isCompleted(_ step: MigrationStep) -> Bool {
        completedSteps.contains(step)
    }
    
    var progress: Double {
        return Double(completedSteps.count) / Double(MigrationStep.allCases.count)
    }
}
