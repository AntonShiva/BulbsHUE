//
//  LightManagement.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import Foundation
import Combine

/// Протокол для управления лампами
/// Следует принципу Interface Segregation - содержит только необходимые методы для управления лампами
protocol LightsManaging: AnyObject {
    /// Список ламп
    var lights: [Light] { get }
    
    /// Publisher для отслеживания изменений в списке ламп
    var lightsPublisher: AnyPublisher<[Light], Never> { get }
    
    /// Установить состояние питания лампы
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - on: Новое состояние питания
    func setPower(for light: Light, on: Bool)
    
    /// Установить яркость лампы (промежуточное значение с дебаунсом)
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - brightness: Яркость в процентах (0-100)
    func setBrightness(for light: Light, brightness: Double)
    
    /// Зафиксировать финальное значение яркости
    /// - Parameters:
    ///   - light: Лампа для изменения
    ///   - brightness: Финальная яркость в процентах (0-100)
    func commitBrightness(for light: Light, brightness: Double)
}

/// Протокол для предоставления информации о группах/комнатах
/// Следует принципу Single Responsibility - только предоставление данных о группах
protocol GroupsProviding: AnyObject {
    /// Список групп (комнат)
    var groups: [HueGroup] { get }
    
    /// Publisher для отслеживания изменений в группах
    var groupsPublisher: AnyPublisher<[HueGroup], Never> { get }
    
    /// Найти группу по ID
    /// - Parameter id: Идентификатор группы
    /// - Returns: Группа или nil если не найдена
    func findGroup(by id: String) -> HueGroup?
}

/// Протокол для предоставления информации о лампе
/// Следует принципу Interface Segregation - только то, что нужно для отображения лампы
protocol LightDisplaying {
    /// Получить название комнаты для лампы
    /// - Parameter light: Лампа
    /// - Returns: Название комнаты
    func getRoomName(for light: Light) -> String
    
    /// Получить тип лампы для отображения
    /// - Parameter light: Лампа
    /// - Returns: Тип лампы
    func getBulbType(for light: Light) -> String
    
    /// Получить иконку лампы
    /// - Parameter light: Лампа
    /// - Returns: Название иконки
    func getBulbIcon(for light: Light) -> String
    
    /// Получить иконку комнаты
    /// - Parameter light: Лампа
    /// - Returns: Название иконки комнаты
    func getRoomIcon(for light: Light) -> String
}

/// Композитный протокол для полного управления лампой
/// Объединяет все необходимые интерфейсы согласно принципу композиции
typealias LightControlling = LightsManaging & GroupsProviding & LightDisplaying
