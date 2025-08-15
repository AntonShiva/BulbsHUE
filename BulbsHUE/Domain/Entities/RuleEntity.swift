//
//  RuleEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - Domain Entity для правила автоматизации
/// Чистая доменная модель правила без зависимостей от API
struct RuleEntity: Equatable, Identifiable {
    let id: String
    let name: String
    let conditions: [RuleConditionEntity]
    let actions: [RuleActionEntity]
    let isEnabled: Bool
    let lastTriggered: Date?
    
    /// Инициализатор из существующей модели HueRule
    init(from rule: HueRule) {
        self.id = rule.id.isEmpty ? UUID().uuidString : rule.id
        self.name = rule.metadata.name
        self.conditions = rule.configuration?.conditions?.map { RuleConditionEntity(from: $0) } ?? []
        self.actions = rule.configuration?.actions?.map { RuleActionEntity(from: $0) } ?? []
        self.isEnabled = rule.enabled
        self.lastTriggered = nil // API не предоставляет эту информацию
    }
    
    /// Инициализатор для создания новой сущности
    init(id: String, 
         name: String, 
         conditions: [RuleConditionEntity], 
         actions: [RuleActionEntity], 
         isEnabled: Bool = true, 
         lastTriggered: Date? = nil) {
        self.id = id
        self.name = name
        self.conditions = conditions
        self.actions = actions
        self.isEnabled = isEnabled
        self.lastTriggered = lastTriggered
    }
}

// MARK: - Rule Condition Entity
struct RuleConditionEntity: Equatable {
    let address: String
    let operator_: String
    let value: String?
    
    /// Инициализатор из API модели
    init(from condition: RuleCondition) {
        self.address = condition.address ?? ""
        self.operator_ = condition.operator ?? "eq"
        self.value = condition.value
    }
    
    init(address: String, operator_: String, value: String? = nil) {
        self.address = address
        self.operator_ = operator_
        self.value = value
    }
}

// MARK: - Rule Action Entity
struct RuleActionEntity: Equatable {
    let address: String
    let method: String
    let body: [String: Any]
    
    /// Инициализатор из API модели
    init(from action: HueRuleAction) {
        self.address = action.address ?? ""
        self.method = action.method ?? "PUT"
        self.body = action.body ?? [:]
    }
    
    init(address: String, method: String, body: [String: Any]) {
        self.address = address
        self.method = method
        self.body = body
    }
    
    static func == (lhs: RuleActionEntity, rhs: RuleActionEntity) -> Bool {
        return lhs.address == rhs.address &&
               lhs.method == rhs.method &&
               NSDictionary(dictionary: lhs.body).isEqual(to: rhs.body)
    }
}
