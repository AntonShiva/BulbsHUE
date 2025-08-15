//
//  RulesViewModel.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import Foundation
import Combine

/// ViewModel для управления правилами автоматизации
class RulesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Список всех правил
    @Published var rules: [HueRule] = []
    
    /// Флаг загрузки
    @Published var isLoading: Bool = false
    
    /// Текущая ошибка
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let apiClient: HueAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: HueAPIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// Загружает все правила
    func loadRules() {
        isLoading = true
        error = nil
        
        apiClient.getAllRules()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] rules in
                    self?.rules = rules
                }
            )
            .store(in: &cancellables)
    }
    
    /// Включает или выключает правило
    /// - Parameters:
    ///   - rule: Правило для изменения
    ///   - enabled: Новое состояние
    func setRuleEnabled(_ rule: HueRule, enabled: Bool) {
        apiClient.setRuleEnabled(id: rule.id, enabled: enabled)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        // Обновляем локальное состояние
                        if let index = self?.rules.firstIndex(where: { $0.id == rule.id }) {
                            self?.rules[index].enabled = enabled
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Создает правило для датчика движения
    /// Избегаем создания конфликтующих правил и циклов
    /// - Parameters:
    ///   - sensorId: ID датчика движения
    ///   - lights: Список ID ламп для включения
    ///   - brightness: Яркость (опционально)
    func createMotionRule(sensorId: String, lights: [String], brightness: Double? = nil) {
        // Проверяем существующие правила чтобы избежать дублирования
        let existingRules = rules.filter { rule in
            rule.configuration?.conditions?.contains { condition in
                condition.address?.contains("/sensors/\(sensorId)/state/presence") ?? false
            } ?? false
        }
        
        if !existingRules.isEmpty {
            print("Предупреждение: Правило для датчика \(sensorId) уже существует")
            error = HueAPIError.conflictingRules
            return
        }
        
        let conditions = [
            RuleCondition(
                address: "/sensors/\(sensorId)/state/presence",
                operator: "eq",
                value: "true"
            ),
            RuleCondition(
                address: "/sensors/\(sensorId)/state/lastupdated",
                operator: "dx",
                value: nil
            )
        ]
        
        var actions: [HueRuleAction] = []
        
        // Оптимизация: используем группу если все лампы в одной комнате
        if lights.count > 3 {
            // Лучше использовать группу для синхронного изменения
            print("Рекомендация: Используйте группу для управления большим количеством ламп")
        }
        
        for lightId in lights {
            var body: [String: Any] = ["on": true]
            if let brightness = brightness {
                body["bri"] = Int(brightness * 254 / 100)
            }
            
            actions.append(HueRuleAction(
                address: "/lights/\(lightId)/state",
                method: "PUT",
                body: body
            ))
        }
        
        createValidatedRule(
            name: "Правило движения",
            conditions: conditions,
            actions: actions
        )
    }
    
    /// Создает правило для кнопки с валидацией
    /// - Parameters:
    ///   - buttonId: ID кнопки
    ///   - buttonEvent: Событие кнопки
    ///   - sceneId: ID сцены для активации
    func createButtonRule(buttonId: String, buttonEvent: ButtonEvent, sceneId: String) {
        let conditions = [
            RuleCondition(
                address: "/sensors/\(buttonId)/state/buttonevent",
                operator: "eq",
                value: String(buttonEvent.rawValue)
            ),
            RuleCondition(
                address: "/sensors/\(buttonId)/state/lastupdated",
                operator: "dx",
                value: nil
            )
        ]
        
        let actions = [
            HueRuleAction(
                address: "/groups/0/action",
                method: "PUT",
                body: ["scene": sceneId]
            )
        ]
        
        createValidatedRule(
            name: "Правило кнопки \(buttonEvent)",
            conditions: conditions,
            actions: actions
        )
    }
    
    /// Создает правило таймера
    /// - Parameters:
    ///   - name: Название правила
    ///   - time: Время срабатывания
    ///   - actions: Действия при срабатывании
    ///   - weekdays: Дни недели (опционально)
    func createTimerRule(name: String, time: String, actions: [HueRuleAction], weekdays: [Int]? = nil) {
        var conditions = [
            RuleCondition(
                address: "/config/localtime",
                operator: "in",
                value: "T\(time):00/T\(time):59"
            )
        ]
        
        // Добавляем условие для дней недели если указаны
        if let weekdays = weekdays, !weekdays.isEmpty {
            let weekdayBitmask = weekdays.reduce(0) { result, day in
                result | (1 << day)
            }
            conditions.append(
                RuleCondition(
                    address: "/config/localtime",
                    operator: "ddx",
                    value: "W\(weekdayBitmask)/T\(time):00"
                )
            )
        }
        
        createValidatedRule(
            name: name,
            conditions: conditions,
            actions: actions
        )
    }
    
    /// Создает правило для уровня освещенности
    /// - Parameters:
    ///   - sensorId: ID датчика освещенности
    ///   - threshold: Пороговое значение в люксах
    ///   - below: true если правило срабатывает при уровне ниже порога
    ///   - actions: Действия при срабатывании
    func createLightLevelRule(sensorId: String, threshold: Int, below: Bool, actions: [HueRuleAction]) {
        let conditions = [
            RuleCondition(
                address: "/sensors/\(sensorId)/state/lightlevel",
                operator: below ? "lt" : "gt",
                value: String(threshold)
            ),
            RuleCondition(
                address: "/sensors/\(sensorId)/state/lastupdated",
                operator: "dx",
                value: nil
            )
        ]
        
        createValidatedRule(
            name: "Правило освещенности",
            conditions: conditions,
            actions: actions
        )
    }
    
    /// Удаляет правило
    /// - Parameter rule: Правило для удаления
    func deleteRule(_ rule: HueRule) {
        // Здесь должен быть вызов API для удаления
        // apiClient.deleteRule(id: rule.id)
        
        // Пока просто удаляем локально
        rules.removeAll { $0.id == rule.id }
    }
    
    /// Удаляет дублирующие правила
    func removeDuplicateRules() {
        var uniqueRules: [String: HueRule] = [:]
        var duplicates: [HueRule] = []
        
        for rule in rules {
            // Создаем уникальный ключ на основе условий
            let key = rule.configuration?.conditions?
                .compactMap { $0.address }
                .sorted()
                .joined(separator: "|") ?? ""
            
            if uniqueRules[key] == nil {
                uniqueRules[key] = rule
            } else {
                // Найдено дублирующее правило
                duplicates.append(rule)
                print("Найдено дублирующее правило: \(rule.metadata.name)")
            }
        }
        
        // Удаляем дубликаты
        for duplicate in duplicates {
            deleteRule(duplicate)
        }
        
        rules = Array(uniqueRules.values)
    }
    
    /// Валидирует правило перед созданием
    /// - Parameters:
    ///   - conditions: Условия правила
    ///   - actions: Действия правила
    /// - Returns: true если правило валидно
    private func validateRule(conditions: [RuleCondition], actions: [HueRuleAction]) -> Bool {
        // Проверка на циклы: правило не должно изменять тот же сенсор, который его запускает
        for condition in conditions {
            guard let conditionAddress = condition.address else { continue }
            
            for action in actions {
                guard let actionAddress = action.address else { continue }
                
                // Извлекаем ID сенсора из адреса
                if conditionAddress.contains("/sensors/") && actionAddress.contains("/sensors/") {
                    let conditionComponents = conditionAddress.components(separatedBy: "/")
                    let actionComponents = actionAddress.components(separatedBy: "/")
                    
                    if conditionComponents.count > 2 && actionComponents.count > 2 {
                        let conditionSensorId = conditionComponents[2]
                        let actionSensorId = actionComponents[2]
                        
                        if conditionSensorId == actionSensorId {
                            print("Ошибка: Обнаружен цикл - правило пытается изменить тот же сенсор")
                            error = HueAPIError.loopDetected
                            return false
                        }
                    }
                }
            }
        }
        
        // Проверка на конфликтующие действия
        var hasOnAction = false
        var hasOffAction = false
        
        for action in actions {
            if let body = action.body,
               let on = body["on"] as? Bool {
                if on {
                    hasOnAction = true
                } else {
                    hasOffAction = true
                }
            }
        }
        
        if hasOnAction && hasOffAction {
            print("Предупреждение: Правило содержит конфликтующие действия (включение и выключение)")
            error = HueAPIError.conflictingRules
            return false
        }
        
        return true
    }
    
    /// Создает правило с валидацией
    private func createValidatedRule(name: String, conditions: [RuleCondition], actions: [HueRuleAction]) {
        guard validateRule(conditions: conditions, actions: actions) else {
            return
        }
        
        apiClient.createRule(
            name: name,
            conditions: conditions,
            actions: actions
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            },
            receiveValue: { [weak self] rule in
                self?.rules.append(rule)
                print("Правило '\(name)' успешно создано")
            }
        )
        .store(in: &cancellables)
    }
    
    /// Анализирует правила на предмет проблем
    func analyzeRules() -> RuleAnalysisResult {
        var conflicts: [(HueRule, HueRule)] = []
        var loops: [HueRule] = []
        var duplicates: [HueRule] = []
        var inefficient: [HueRule] = []
        
        // Проверка на дубликаты и конфликты
        for i in 0..<rules.count {
            for j in (i+1)..<rules.count {
                let rule1 = rules[i]
                let rule2 = rules[j]
                
                // Проверка на дубликаты
                if areRulesDuplicate(rule1, rule2) {
                    duplicates.append(rule2)
                }
                
                // Проверка на конфликты
                if areRulesConflicting(rule1, rule2) {
                    conflicts.append((rule1, rule2))
                }
            }
            
            // Проверка на циклы
            if hasLoop(rules[i]) {
                loops.append(rules[i])
            }
            
            // Проверка на неэффективность
            if isInefficient(rules[i]) {
                inefficient.append(rules[i])
            }
        }
        
        return RuleAnalysisResult(
            totalRules: rules.count,
            conflicts: conflicts,
            loops: loops,
            duplicates: duplicates,
            inefficientRules: inefficient
        )
    }
    
    /// Проверяет являются ли правила дубликатами
    private func areRulesDuplicate(_ rule1: HueRule, _ rule2: HueRule) -> Bool {
        guard let conditions1 = rule1.configuration?.conditions,
              let conditions2 = rule2.configuration?.conditions else { return false }
        
        // Простая проверка: одинаковые условия
        let addresses1 = conditions1.compactMap { $0.address }.sorted()
        let addresses2 = conditions2.compactMap { $0.address }.sorted()
        
        return addresses1 == addresses2
    }
    
    /// Проверяет конфликтуют ли правила
    private func areRulesConflicting(_ rule1: HueRule, _ rule2: HueRule) -> Bool {
        guard let conditions1 = rule1.configuration?.conditions,
              let conditions2 = rule2.configuration?.conditions,
              let actions1 = rule1.configuration?.actions,
              let actions2 = rule2.configuration?.actions else { return false }
        
        // Проверяем, срабатывают ли правила на одинаковые условия
        let triggers1 = conditions1.compactMap { $0.address }.filter { $0.contains("buttonevent") || $0.contains("presence") }
        let triggers2 = conditions2.compactMap { $0.address }.filter { $0.contains("buttonevent") || $0.contains("presence") }
        
        if !triggers1.isEmpty && triggers1 == triggers2 {
            // Проверяем противоположные действия
            for action1 in actions1 {
                for action2 in actions2 {
                    if action1.address == action2.address {
                        if let on1 = action1.body?["on"] as? Bool,
                           let on2 = action2.body?["on"] as? Bool,
                           on1 != on2 {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    /// Проверяет есть ли цикл в правиле
    private func hasLoop(_ rule: HueRule) -> Bool {
        guard let conditions = rule.configuration?.conditions,
              let actions = rule.configuration?.actions else { return false }
        
        return !validateRule(conditions: conditions, actions: actions)
    }
    
    /// Проверяет эффективность правила
    private func isInefficient(_ rule: HueRule) -> Bool {
        guard let actions = rule.configuration?.actions else { return false }
        
        // Правило неэффективно если управляет больше чем 3 лампами индивидуально
        let lightActions = actions.filter { $0.address?.contains("/lights/") ?? false }
        return lightActions.count > 3
    }
    
    // MARK: - Computed Properties
    
    /// Активные правила
    var activeRules: [HueRule] {
        rules.filter { $0.enabled }
    }
    
    /// Неактивные правила
    var inactiveRules: [HueRule] {
        rules.filter { !$0.enabled }
    }
    
    /// Правила с потенциальными проблемами
    var problematicRules: [HueRule] {
        rules.filter { rule in
            // Проверяем на потенциальные циклы или конфликты
            guard let conditions = rule.configuration?.conditions,
                  let actions = rule.configuration?.actions else { return false }
            
            return !validateRule(conditions: conditions, actions: actions)
        }
    }
    
    /// Правила по типам триггеров
    var rulesByTriggerType: [String: [HueRule]] {
        var grouped: [String: [HueRule]] = [:]
        
        for rule in rules {
            guard let conditions = rule.configuration?.conditions else { continue }
            
            for condition in conditions {
                if let address = condition.address {
                    if address.contains("buttonevent") {
                        grouped["button", default: []].append(rule)
                    } else if address.contains("presence") {
                        grouped["motion", default: []].append(rule)
                    } else if address.contains("lightlevel") {
                        grouped["lightLevel", default: []].append(rule)
                    } else if address.contains("temperature") {
                        grouped["temperature", default: []].append(rule)
                    } else if address.contains("localtime") {
                        grouped["timer", default: []].append(rule)
                    }
                }
            }
        }
        
        return grouped
    }
    
    /// Статистика правил
    var statistics: RuleStatistics {
        RuleStatistics(
            total: rules.count,
            active: activeRules.count,
            inactive: inactiveRules.count,
            problematic: problematicRules.count,
            byType: rulesByTriggerType.mapValues { $0.count }
        )
    }
}

// MARK: - Supporting Types

/// Результат анализа правил
struct RuleAnalysisResult {
    let totalRules: Int
    let conflicts: [(HueRule, HueRule)]
    let loops: [HueRule]
    let duplicates: [HueRule]
    let inefficientRules: [HueRule]
    
    var hasIssues: Bool {
        !conflicts.isEmpty || !loops.isEmpty || !duplicates.isEmpty || !inefficientRules.isEmpty
    }
    
    var summary: String {
        var issues: [String] = []
        
        if !conflicts.isEmpty {
            issues.append("\(conflicts.count) конфликтующих правил")
        }
        if !loops.isEmpty {
            issues.append("\(loops.count) правил с циклами")
        }
        if !duplicates.isEmpty {
            issues.append("\(duplicates.count) дублирующих правил")
        }
        if !inefficientRules.isEmpty {
            issues.append("\(inefficientRules.count) неэффективных правил")
        }
        
        return issues.isEmpty ? "Проблем не обнаружено" : issues.joined(separator: ", ")
    }
}

/// Статистика правил
struct RuleStatistics {
    let total: Int
    let active: Int
    let inactive: Int
    let problematic: Int
    let byType: [String: Int]
    
    var activePercentage: Double {
        total > 0 ? Double(active) / Double(total) * 100 : 0
    }
}
