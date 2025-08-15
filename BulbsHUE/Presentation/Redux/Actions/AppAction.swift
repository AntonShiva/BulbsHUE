//
//  AppAction.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - App Action
/// Все возможные действия в приложении
enum AppAction: Equatable {
    // MARK: - Light Actions
    case light(LightAction)
    
    // MARK: - Bridge Actions
    case bridge(BridgeAction)
    
    // MARK: - Scene Actions
    case scene(SceneAction)
    
    // MARK: - Group Actions
    case group(GroupAction)
    
    // MARK: - Sensor Actions
    case sensor(SensorAction)
    
    // MARK: - Rule Actions
    case rule(RuleAction)
    
    // MARK: - UI Actions
    case ui(UIAction)
}

// MARK: - Light Action
enum LightAction: Equatable {
    // Queries
    case loadLights
    case loadAssignedLights
    case searchLights(query: String, type: SearchType)
    
    // Commands
    case toggleLight(id: String, brightness: Double?)
    case updateBrightness(id: String, brightness: Double)
    case updateColor(id: String, color: LightColor)
    case updateColorTemperature(id: String, temperature: Int)
    case addToEnvironment(id: String, userSubtype: String, userIcon: String)
    case removeFromEnvironment(id: String)
    
    // Results
    case lightsLoaded([LightEntity])
    case assignedLightsLoaded([LightEntity])
    case searchResultsLoaded([LightEntity])
    case lightUpdated(LightEntity)
    case lightUpdateFailed(id: String, error: String)
    
    // State
    case setSelectedLight(LightEntity?)
    case setLoading(Bool)
    case setError(String?)
    
    enum SearchType: Equatable {
        case network
        case serialNumber
    }
}

// MARK: - Bridge Action
enum BridgeAction: Equatable {
    case discoverBridges
    case bridgesDiscovered([BridgeEntity])
    case connectToBridge(BridgeEntity)
    case bridgeConnected(BridgeEntity, applicationKey: String)
    case setConnectionStatus(ConnectionStatus)
    case loadCapabilities
    case capabilitiesLoaded(BridgeCapabilities)
    case setError(String?)
}

// MARK: - Scene Action
enum SceneAction: Equatable {
    case loadScenes
    case scenesLoaded([SceneEntity])
    case activateScene(String)
    case sceneActivated(String)
    case createScene(name: String, lightIds: [String])
    case sceneCreated(SceneEntity)
    case deleteScene(String)
    case sceneDeleted(String)
    case setLoading(Bool)
    case setError(String?)
}

// MARK: - Group Action
enum GroupAction: Equatable {
    case loadGroups
    case groupsLoaded([GroupEntity])
    case updateGroupState(id: String, isOn: Bool, brightness: Double?)
    case groupUpdated(GroupEntity)
    case createGroup(name: String, lightIds: [String])
    case groupCreated(GroupEntity)
    case deleteGroup(String)
    case groupDeleted(String)
    case setSelectedGroup(GroupEntity?)
    case setLoading(Bool)
    case setError(String?)
}

// MARK: - Sensor Action
enum SensorAction: Equatable {
    case loadSensors
    case sensorsLoaded([SensorEntity])
    case sensorUpdated(SensorEntity)
    case setLoading(Bool)
    case setError(String?)
}

// MARK: - Rule Action
enum RuleAction: Equatable {
    case loadRules
    case rulesLoaded([RuleEntity])
    case createRule(name: String, conditions: [RuleConditionEntity], actions: [RuleActionEntity])
    case ruleCreated(RuleEntity)
    case deleteRule(String)
    case ruleDeleted(String)
    case toggleRule(id: String, enabled: Bool)
    case ruleToggled(String, Bool)
    case setLoading(Bool)
    case setError(String?)
}

// MARK: - UI Action
enum UIAction: Equatable {
    case setAppActive(Bool)
    case setShowSetup(Bool)
    case setSelectedTab(Int)
    case updatePerformanceMetrics(PerformanceMetrics)
    case incrementEventsReceived
    case incrementAPICallsCount
}
