//
//  HueAPIClient+Rules.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Rules Endpoints
    
    /// Получает список всех правил
    /// - Returns: Combine Publisher со списком правил
    func getAllRules() -> AnyPublisher<[HueRule], Error> {
        let endpoint = "/clip/v2/resource/behavior_script"
        return performRequestHTTPS<RulesResponse>(endpoint: endpoint, method: "GET")
            .map { (response: RulesResponse) in
                response.data
            }
            .eraseToAnyPublisher()
    }
    
    /// Создает новое правило
    /// - Parameters:
    ///   - name: Название правила
    ///   - conditions: Условия срабатывания
    ///   - actions: Действия при срабатывании
    /// - Returns: Combine Publisher с созданным правилом
    func createRule(name: String, conditions: [RuleCondition], actions: [HueRuleAction]) -> AnyPublisher<HueRule, Error> {
        let endpoint = "/clip/v2/resource/behavior_script"
        
        var rule = HueRule()
        rule.metadata.name = name
        rule.configuration = RuleConfiguration(
            conditions: conditions,
            actions: actions
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(rule)
            
            return performRequestHTTPS<RuleResponse>(endpoint: endpoint, method: "POST", body: data)
                .map { (response: RuleResponse) in
                    response.data.first ?? HueRule()
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Включает или выключает правило
    /// - Parameters:
    ///   - id: Идентификатор правила
    ///   - enabled: Флаг включения
    /// - Returns: Combine Publisher с результатом
    func setRuleEnabled(id: String, enabled: Bool) -> AnyPublisher<Bool, Error> {
        let endpoint = "/clip/v2/resource/behavior_script/\(id)"
        
        let body = ["enabled": enabled]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            
            return performRequestHTTPS<GenericResponse>(endpoint: endpoint, method: "PUT", body: data)
                .map { (_: GenericResponse) in true }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+Rules.swift
 
 Описание:
 Расширение HueAPIClient для управления правилами автоматизации.
 
 Основные компоненты:
 - getAllRules - получение списка всех правил
 - createRule - создание нового правила
 - setRuleEnabled - включение/выключение правила
 
 Зависимости:
 - HueAPIClient базовый класс
 - HueRule, RuleCondition, RuleAction, RuleConfiguration модели
 - performRequestHTTPS для сетевых запросов
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+Networking.swift - сетевые методы
 */
