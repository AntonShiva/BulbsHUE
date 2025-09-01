//
//  EnvironmentEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import Foundation

// MARK: - Environment Scene Entity

/// Доменная сущность для пресета сцены окружения
struct EnvironmentSceneEntity: Identifiable, Equatable {
    let id: String
    let name: String
    let imageAssetName: String
    let section: EnvironmentSection
    let filterType: EnvironmentFilterType
    let isFavorite: Bool
    var isSelected: Bool = false
    
    init(
        id: String = UUID().uuidString,
        name: String,
        imageAssetName: String,
        section: EnvironmentSection,
        filterType: EnvironmentFilterType,
        isFavorite: Bool = false,
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.imageAssetName = imageAssetName
        self.section = section
        self.filterType = filterType
        self.isFavorite = isFavorite
        self.isSelected = isSelected
    }
}

// MARK: - Environment Filter Types

/// Типы фильтров для сцен окружения
enum EnvironmentFilterType: String, CaseIterable, RawRepresentable {
    case colorPicker = "colorPicker"
    case pastel = "pastel"
    case bright = "bright"
    
    var displayName: String {
        switch self {
        case .colorPicker: return "COLOR PICKER"
        case .pastel: return "PASTEL"
        case .bright: return "BRIGHT"
        }
    }
}

// MARK: - Environment Sections

/// Секции для группировки сцен
enum EnvironmentSection: String, CaseIterable, RawRepresentable {
    case section1 = "section1"
    case section2 = "section2"
    case section3 = "section3"
    
    var displayName: String {
        switch self {
        case .section1: return "SECTION 1"
        case .section2: return "SECTION 2"
        case .section3: return "SECTION 3"
        }
    }
}

// MARK: - Environment Scene Collection

/// Коллекция сцен для определенного фильтра и секции
struct EnvironmentSceneCollection {
    let filterType: EnvironmentFilterType
    let section: EnvironmentSection
    let scenes: [EnvironmentSceneEntity]
    
    /// Фильтрованные сцены с учетом избранного
    func filteredScenes(showFavoritesOnly: Bool) -> [EnvironmentSceneEntity] {
        guard showFavoritesOnly else { return scenes }
        return scenes.filter { $0.isFavorite }
    }
}
