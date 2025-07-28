//
//  Common.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// XY координаты цвета
struct XYColor: Codable {
    /// X координата (0.0-1.0)
    var x: Double = 0.0
    
    /// Y координата (0.0-1.0)
    var y: Double = 0.0
}

/// Цветовая гамма
/// Gamut A: Legacy (Bloom, Aura, Light Strips, Iris)
/// Gamut B: Старые модели Hue bulbs
/// Gamut C: Новые модели Hue bulbs
struct Gamut: Codable {
    /// Красная точка
    var red: XYColor?
    
    /// Зеленая точка
    var green: XYColor?
    
    /// Синяя точка
    var blue: XYColor?
}

/// Идентификатор ресурса
struct ResourceIdentifier: Codable {
    /// ID ресурса
    var rid: String?
    
    /// Тип ресурса
    var rtype: String?
}

/// Данные о продукте
struct ProductData: Codable {
    /// Модель
    var model_id: String?
    
    /// Производитель
    var manufacturer_name: String?
    
    /// Название продукта
    var product_name: String?
    
    /// Архетип продукта
    var product_archetype: String?
    
    /// Сертификация
    var certified: Bool?
    
    /// Версия ПО
    var software_version: String?
}
