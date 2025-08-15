//
//  RuleRepositoryProtocol.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Rule Repository Protocol
protocol RuleRepositoryProtocol {
    // MARK: - Read Operations
    func getAllRules() -> AnyPublisher<[RuleEntity], Error>
    func getRule(by id: String) -> AnyPublisher<RuleEntity?, Error>
    func getEnabledRules() -> AnyPublisher<[RuleEntity], Error>
    
    // MARK: - Write Operations
    func createRule(name: String, conditions: [RuleConditionEntity], actions: [RuleActionEntity]) -> AnyPublisher<RuleEntity, Error>
    func updateRule(_ rule: RuleEntity) -> AnyPublisher<Void, Error>
    func deleteRule(id: String) -> AnyPublisher<Void, Error>
    func toggleRule(id: String, isEnabled: Bool) -> AnyPublisher<Void, Error>
    
    // MARK: - Reactive Streams
    var rulesStream: AnyPublisher<[RuleEntity], Never> { get }
    func ruleStream(for id: String) -> AnyPublisher<RuleEntity?, Never>
}
