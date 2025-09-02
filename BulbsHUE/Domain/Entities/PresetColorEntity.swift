//
//  PresetColorEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 2.09.2025.
//

import Foundation
import SwiftUI

// MARK: - Preset Color Entity

/// Доменная сущность для управления цветами пресетов
/// Содержит набор цветов для применения к лампам в сцене
struct PresetColorEntity: Identifiable, Equatable, Codable {
    let id: String
    let sceneId: String
    let colors: [PresetSceneColor]
    
    init(
        id: String = UUID().uuidString,
        sceneId: String,
        colors: [PresetSceneColor]
    ) {
        self.id = id
        self.sceneId = sceneId
        self.colors = colors
    }
}

// MARK: - Preset Scene Color

/// Отдельный цвет в пресете с приоритетом для распределения по лампам
struct PresetSceneColor: Identifiable, Equatable, Codable {
    let id: String
    let hexColor: String
    let priority: Int // Приоритет для назначения лампам (0 - высший)
    
    init(
        id: String = UUID().uuidString,
        hexColor: String,
        priority: Int
    ) {
        self.id = id
        self.hexColor = hexColor
        self.priority = priority
    }
    
    /// Конвертирует hex цвет в SwiftUI Color
    var color: Color {
        return Color(hex: hexColor)
    }
}

// MARK: - Color Distribution Strategy

/// Стратегия распределения цветов по лампам согласно документации Philips Hue
enum ColorDistributionStrategy {
    case balanced      // Распределение по кругу
    case dominantFirst // Доминирующие цвета первыми
    case adaptive      // Адаптивное распределение в зависимости от количества ламп
    
    /// Распределяет цвета по лампам согласно логике Philips Hue
    /// - Parameters:
    ///   - colors: Массив цветов пресета (до 5 цветов)
    ///   - lightCount: Количество ламп в комнате/группе
    /// - Returns: Массив цветов для каждой лампы
    func distributeColors(_ colors: [PresetSceneColor], forLightCount lightCount: Int) -> [Color] {
        let sortedColors = colors.sorted { $0.priority < $1.priority }
        let swiftUIColors = sortedColors.map { $0.color }
        
        guard !swiftUIColors.isEmpty else {
            return Array(repeating: Color.white, count: lightCount)
        }
        
        switch self {
        case .balanced:
            return distributeBalanced(swiftUIColors, lightCount: lightCount)
        case .dominantFirst:
            return distributeDominantFirst(swiftUIColors, lightCount: lightCount)
        case .adaptive:
            return distributeAdaptive(swiftUIColors, lightCount: lightCount)
        }
    }
    
    /// Равномерное распределение цветов по кругу
    private func distributeBalanced(_ colors: [Color], lightCount: Int) -> [Color] {
        var result: [Color] = []
        
        for i in 0..<lightCount {
            let colorIndex = i % colors.count
            result.append(colors[colorIndex])
        }
        
        return result
    }
    
    /// Доминирующие цвета назначаются первыми лампам
    private func distributeDominantFirst(_ colors: [Color], lightCount: Int) -> [Color] {
        var result: [Color] = []
        
        // Если ламп меньше или равно количеству цветов
        if lightCount <= colors.count {
            for i in 0..<lightCount {
                result.append(colors[i])
            }
        } else {
            // Если ламп больше чем цветов, повторяем схему
            for i in 0..<lightCount {
                let colorIndex = i % colors.count
                result.append(colors[colorIndex])
            }
        }
        
        return result
    }
    
    /// Адаптивное распределение в зависимости от количества ламп
    private func distributeAdaptive(_ colors: [Color], lightCount: Int) -> [Color] {
        switch lightCount {
        case 1:
            // Одна лампа - первый (доминирующий) цвет
            return [colors.first ?? Color.white]
        case 2:
            // Две лампы - первые два цвета или дублируем первый
            if colors.count >= 2 {
                return [colors[0], colors[1]]
            } else {
                return [colors[0], colors[0]]
            }
        case 3:
            // Три лампы - первые три цвета или распределяем доступные
            if colors.count >= 3 {
                return [colors[0], colors[1], colors[2]]
            } else {
                return distributeBalanced(colors, lightCount: 3)
            }
        case 4:
            // Четыре лампы - используем первые 4 цвета или распределяем
            if colors.count >= 4 {
                return [colors[0], colors[1], colors[2], colors[3]]
            } else {
                return distributeBalanced(colors, lightCount: 4)
            }
        case 5:
            // Пять ламп - все пять цветов
            if colors.count >= 5 {
                return Array(colors.prefix(5))
            } else {
                return distributeBalanced(colors, lightCount: 5)
            }
        default:
            // Больше 5 ламп - используем циклическое распределение
            return distributeBalanced(colors, lightCount: lightCount)
        }
    }
}
