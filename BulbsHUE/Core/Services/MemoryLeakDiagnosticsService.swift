//
//  MemoryLeakDiagnosticsService.swift
//  BulbsHUE
//
//  Created by Claude Code on 04.09.2025.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Memory Diagnostics Service

/// Сервис для мониторинга и диагностики утечек памяти в приложении
/// Отслеживает количество активных объектов и предоставляет диагностическую информацию
@MainActor
final class MemoryLeakDiagnosticsService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MemoryLeakDiagnosticsService()
    
    // MARK: - Published Properties
    
    /// Статистика по активным объектам
    @Published private(set) var activeObjectsStats: [String: Int] = [:]
    
    /// Предупреждения об утечках памяти
    @Published private(set) var memoryWarnings: [MemoryWarning] = []
    
    /// Флаг включения диагностики (только для DEBUG)
    @Published var isDiagnosticsEnabled: Bool = false {
        didSet {
            if isDiagnosticsEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    // MARK: - Private Properties
    
    /// Реестр активных объектов
    private var objectRegistry: [String: WeakObjectContainer] = [:]
    
    /// Таймер для периодической проверки
    private var monitoringTimer: Timer?
    
    /// Пороговые значения для предупреждений
    private let warningThresholds: [String: Int] = [
        "ViewModels": 20,
        "Repositories": 5,
        "Services": 15,
        "Subjects": 50,
        "Cancellables": 100
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Включаем диагностику только в DEBUG режиме
        #if DEBUG
        isDiagnosticsEnabled = true
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Зарегистрировать объект для отслеживания
    /// - Parameters:
    ///   - object: Объект для отслеживания
    ///   - category: Категория объекта (ViewModel, Repository, Service и т.д.)
    ///   - identifier: Уникальный идентификатор объекта
    func registerObject<T: AnyObject>(_ object: T, category: String, identifier: String? = nil) {
        guard isDiagnosticsEnabled else { return }
        
        let objectId = identifier ?? "\(category)_\(ObjectIdentifier(object).hashValue)"
        let container = WeakObjectContainer(object: object, category: category, createdAt: Date())
        
        objectRegistry[objectId] = container
        updateStats()
        
        print("📊 MemoryDiagnostics: Зарегистрирован \(category) - \(objectId)")
    }
    
    /// Отменить регистрацию объекта
    /// - Parameter identifier: Идентификатор объекта
    func unregisterObject(_ identifier: String) {
        guard isDiagnosticsEnabled else { return }
        
        if let container = objectRegistry.removeValue(forKey: identifier) {
            print("📊 MemoryDiagnostics: Отменена регистрация \(container.category) - \(identifier)")
            updateStats()
        }
    }
    
    /// Получить детальную статистику
    /// - Returns: Детальная диагностическая информация
    func getDiagnosticsReport() -> DiagnosticsReport {
        cleanupDeadReferences()
        
        let categorizedObjects = Dictionary(grouping: objectRegistry.values) { $0.category }
        let categoryStats = categorizedObjects.mapValues { $0.count }
        
        let totalObjects = objectRegistry.count
        let oldestObject = objectRegistry.values.min { $0.createdAt < $1.createdAt }
        
        return DiagnosticsReport(
            totalActiveObjects: totalObjects,
            categoryBreakdown: categoryStats,
            oldestObjectAge: oldestObject?.createdAt.timeIntervalSinceNow.magnitude ?? 0,
            warnings: memoryWarnings,
            lastUpdated: Date()
        )
    }
    
    /// Принудительная проверка на утечки памяти
    func performMemoryLeakCheck() {
        guard isDiagnosticsEnabled else { return }
        
        print("🔍 MemoryDiagnostics: Выполняем проверку утечек памяти...")
        
        cleanupDeadReferences()
        updateStats()
        checkForMemoryLeaks()
        
        print("✅ MemoryDiagnostics: Проверка завершена. Активных объектов: \(objectRegistry.count)")
    }
    
    /// Очистить все предупреждения
    func clearWarnings() {
        memoryWarnings.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Запуск мониторинга
    private func startMonitoring() {
        guard monitoringTimer == nil else { return }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performMemoryLeakCheck()
            }
        }
        
        print("🚀 MemoryDiagnostics: Мониторинг запущен")
    }
    
    /// Остановка мониторинга
    private func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        print("⏹️ MemoryDiagnostics: Мониторинг остановлен")
    }
    
    /// Обновление статистики
    private func updateStats() {
        let categorizedObjects = Dictionary(grouping: objectRegistry.values) { $0.category }
        activeObjectsStats = categorizedObjects.mapValues { $0.count }
    }
    
    /// Очистка мертвых ссылок
    private func cleanupDeadReferences() {
        let beforeCount = objectRegistry.count
        
        objectRegistry = objectRegistry.compactMapValues { container in
            container.object != nil ? container : nil
        }
        
        let removedCount = beforeCount - objectRegistry.count
        if removedCount > 0 {
            print("🧹 MemoryDiagnostics: Очищено \(removedCount) мертвых ссылок")
        }
    }
    
    /// Проверка на утечки памяти
    private func checkForMemoryLeaks() {
        let currentStats = activeObjectsStats
        
        for (category, threshold) in warningThresholds {
            if let count = currentStats[category], count > threshold {
                let warning = MemoryWarning(
                    category: category,
                    currentCount: count,
                    threshold: threshold,
                    severity: count > threshold * 2 ? .critical : .warning,
                    timestamp: Date()
                )
                
                // Добавляем предупреждение, если его еще нет
                if !memoryWarnings.contains(where: { $0.category == category && $0.severity == warning.severity }) {
                    memoryWarnings.append(warning)
                    print("⚠️ MemoryDiagnostics: \(warning.severity.emoji) \(category): \(count)/\(threshold)")
                }
            }
        }
        
        // Удаляем старые предупреждения (старше 5 минут)
        let cutoffDate = Date().addingTimeInterval(-300)
        memoryWarnings.removeAll { $0.timestamp < cutoffDate }
    }
    
    // MARK: - Cleanup
    
    deinit {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        objectRegistry.removeAll()
    }
}

// MARK: - Supporting Types

/// Контейнер для слабых ссылок на объекты
private class WeakObjectContainer {
    weak var object: AnyObject?
    let category: String
    let createdAt: Date
    
    init(object: AnyObject, category: String, createdAt: Date) {
        self.object = object
        self.category = category
        self.createdAt = createdAt
    }
}

/// Предупреждение об утечке памяти
struct MemoryWarning: Identifiable, Equatable {
    let id = UUID()
    let category: String
    let currentCount: Int
    let threshold: Int
    let severity: Severity
    let timestamp: Date
    
    enum Severity: String, CaseIterable {
        case warning = "Warning"
        case critical = "Critical"
        
        var emoji: String {
            switch self {
            case .warning: return "⚠️"
            case .critical: return "🚨"
            }
        }
        
        var color: Color {
            switch self {
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
    
    var description: String {
        return "\(severity.emoji) \(category): \(currentCount) объектов (лимит: \(threshold))"
    }
}

/// Детальный отчет диагностики
struct DiagnosticsReport {
    let totalActiveObjects: Int
    let categoryBreakdown: [String: Int]
    let oldestObjectAge: TimeInterval
    let warnings: [MemoryWarning]
    let lastUpdated: Date
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    var hasCriticalWarnings: Bool {
        return warnings.contains { $0.severity == .critical }
    }
}

// MARK: - Extensions

extension MemoryLeakDiagnosticsService {
    /// Создать mock сервис для превью
    static func createMock() -> MemoryLeakDiagnosticsService {
        let service = MemoryLeakDiagnosticsService()
        service.isDiagnosticsEnabled = false // Отключаем для mock
        
        // Добавляем моковые данные
        service.activeObjectsStats = [
            "ViewModels": 5,
            "Repositories": 3,
            "Services": 8,
            "Subjects": 25
        ]
        
        service.memoryWarnings = [
            MemoryWarning(
                category: "Subjects",
                currentCount: 55,
                threshold: 50,
                severity: .warning,
                timestamp: Date()
            )
        ]
        
        return service
    }
}

// MARK: - Global Registration Helpers

/// Глобальные функции для удобной регистрации объектов
extension MemoryLeakDiagnosticsService {
    
    /// Зарегистрировать ViewModel
    static func registerViewModel<T: ObservableObject>(_ viewModel: T, name: String? = nil) {
        let identifier = name ?? String(describing: type(of: viewModel))
        shared.registerObject(viewModel, category: "ViewModels", identifier: identifier)
    }
    
    /// Зарегистрировать Repository
    static func registerRepository<T: AnyObject>(_ repository: T, name: String? = nil) {
        let identifier = name ?? String(describing: type(of: repository))
        shared.registerObject(repository, category: "Repositories", identifier: identifier)
    }
    
    /// Зарегистрировать Service
    static func registerService<T: AnyObject>(_ service: T, name: String? = nil) {
        let identifier = name ?? String(describing: type(of: service))
        shared.registerObject(service, category: "Services", identifier: identifier)
    }
    
    /// Зарегистрировать Subject
    static func registerSubject<T: AnyObject>(_ subject: T, name: String? = nil) {
        let identifier = name ?? String(describing: type(of: subject))
        shared.registerObject(subject, category: "Subjects", identifier: identifier)
    }
}