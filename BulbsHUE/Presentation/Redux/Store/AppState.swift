//
//  AppState.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - App State
/// Глобальное состояние приложения
struct AppState: Equatable {
    nonisolated init() {
        self.lights = AppLightState()
        self.bridge = BridgeState()
        self.scenes = AppSceneState()
        self.groups = AppGroupState()
        self.sensors = SensorState()
        self.rules = RuleState()
        self.ui = UIState()
    }
    var lights: AppLightState = AppLightState()
    var bridge: BridgeState = BridgeState()
    var scenes: AppSceneState = AppSceneState()
    var groups: AppGroupState = AppGroupState()
    var sensors: SensorState = SensorState()
    var rules: RuleState = RuleState()
    var ui: UIState = UIState()
}

// MARK: - Light State
struct AppLightState: Equatable {
    var allLights: [LightEntity] = []
    var assignedLights: [LightEntity] = []
    var selectedLight: LightEntity? = nil
    var searchResults: [LightEntity] = []
    var isLoading: Bool = false
    var error: String? = nil
    
    // Computed properties
    var availableLights: [LightEntity] {
        allLights.filter { light in
            !assignedLights.contains { $0.id == light.id }
        }
    }
    
    var reachableLights: [LightEntity] {
        assignedLights.filter { $0.isReachable }
    }
}



// MARK: - Bridge State
struct BridgeState: Equatable {
    var currentBridge: BridgeEntity? = nil
    var discoveredBridges: [BridgeEntity] = []
    var connectionStatus: ConnectionStatus = .disconnected
    var applicationKey: String? = nil
    var capabilities: BridgeCapabilities? = nil
    var isDiscovering: Bool = false
    var error: String? = nil
}

enum ConnectionStatus: Equatable {
    case disconnected
    case searching
    case discovered
    case connecting
    case needsAuthentication
    case connected
    case error(String)
}

// MARK: - Scene State
struct AppSceneState: Equatable {
    var scenes: [SceneEntity] = []
    var activeScene: SceneEntity? = nil
    var isLoading: Bool = false
    var error: String? = nil
}

// MARK: - Group State
struct AppGroupState: Equatable {
    var groups: [GroupEntity] = []
    var selectedGroup: GroupEntity? = nil
    var isLoading: Bool = false
    var error: String? = nil
}

// MARK: - Sensor State
struct SensorState: Equatable {
    var sensors: [SensorEntity] = []
    var isLoading: Bool = false
    var error: String? = nil
}

// MARK: - Rule State
struct RuleState: Equatable {
    var rules: [RuleEntity] = []
    var isLoading: Bool = false
    var error: String? = nil
}

// MARK: - UI State
struct UIState: Equatable {
    var isAppActive: Bool = true
    var showSetup: Bool = false
    var selectedTab: Int = 0
    var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
}

struct PerformanceMetrics: Equatable {
    var eventsReceived: Int = 0
    var apiCallsCount: Int = 0
    var rateLimitHits: Int = 0
    var bufferOverflows: Int = 0
    var averageLatency: Double = 0
    var lastUpdateTime: Date? = nil
    
    mutating func reset() {
        eventsReceived = 0
        apiCallsCount = 0
        rateLimitHits = 0
        bufferOverflows = 0
        averageLatency = 0
        lastUpdateTime = nil
    }
}
