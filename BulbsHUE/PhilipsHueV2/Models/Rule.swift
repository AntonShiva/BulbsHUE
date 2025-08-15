//
//  Rule.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// Модель правила автоматизации
struct HueRule: Codable, Identifiable {
    /// Уникальный идентификатор
    var id: String = UUID().uuidString
    
    /// Тип ресурса
    var type: String = "behavior_script"
    
    /// Метаданные
    var metadata: RuleMetadata = RuleMetadata()
    
    /// Конфигурация правила
    var configuration: RuleConfiguration?
    
    /// Включено ли правило
    var enabled: Bool = true
    
    /// Миграция из v1
    var migrated_from: String?
}

/// Метаданные правила
struct RuleMetadata: Codable {
    /// Название правила
    var name: String = "Новое правило"
}

/// Конфигурация правила
struct RuleConfiguration: Codable {
    /// Условия срабатывания
    var conditions: [RuleCondition]?
    
    /// Действия при срабатывании
    var actions: [HueRuleAction]?
}

/// Условие правила
struct RuleCondition: Codable {
    /// Адрес ресурса для проверки
    var address: String?
    
    /// Оператор сравнения (eq, dx, ddx, lt, gt, in)
    var `operator`: String?
    
    /// Значение для сравнения
    var value: String?
}

/// Действие правила
struct HueRuleAction: Codable {
    /// Адрес ресурса для изменения
    var address: String?
    
    /// HTTP метод
    var method: String?
    
    /// Тело запроса
    var body: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case address, method, body
    }
    
    init(address: String? = nil, method: String? = nil, body: [String: Any]? = nil) {
        self.address = address
        self.method = method
        self.body = body
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        
        if let bodyData = try? container.decode([String: AnyCodable].self, forKey: .body) {
            body = bodyData.mapValues { $0.wrappedValue }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(method, forKey: .method)
        
        if let body = body {
            let codableBody = body.mapValues { AnyCodable($0) }
            try container.encode(codableBody, forKey: .body)
        }
    }
}
