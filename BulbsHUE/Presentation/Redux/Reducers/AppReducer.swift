//
//  AppReducer.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - App Reducer
/// Главный редьюсер приложения, объединяющий все подредьюсеры
func appReducer(state: AppState, action: AppAction) -> AppState {
    var newState = state
    
    switch action {
    case .light(let lightAction):
        newState.lights = lightReducer(state: state.lights, action: lightAction)
        
    case .bridge(let bridgeAction):
        newState.bridge = bridgeReducer(state: state.bridge, action: bridgeAction)
        
    case .scene(let sceneAction):
        newState.scenes = sceneReducer(state: state.scenes, action: sceneAction)
        
    case .group(let groupAction):
        newState.groups = groupReducer(state: state.groups, action: groupAction)
        
    case .sensor(let sensorAction):
        newState.sensors = sensorReducer(state: state.sensors, action: sensorAction)
        
    case .rule(let ruleAction):
        newState.rules = ruleReducer(state: state.rules, action: ruleAction)
        
    case .ui(let uiAction):
        newState.ui = uiReducer(state: state.ui, action: uiAction)
    }
    
    return newState
}

// MARK: - Light Reducer
func lightReducer(state: AppLightState, action: LightAction) -> AppLightState {
    var newState = state
    
    switch action {
    case .loadLights:
        newState.isLoading = true
        newState.error = nil
        
    case .lightsLoaded(let lights):
        newState.allLights = lights
        newState.isLoading = false
        newState.error = nil
        
    case .loadAssignedLights:
        newState.isLoading = true
        newState.error = nil
        
    case .assignedLightsLoaded(let lights):
        newState.assignedLights = lights
        newState.isLoading = false
        newState.error = nil
        
    case .searchLights(_, _):
        newState.isLoading = true
        newState.error = nil
        newState.searchResults = []
        
    case .searchResultsLoaded(let lights):
        newState.searchResults = lights
        newState.isLoading = false
        newState.error = nil
        
    case .lightUpdated(let light):
        // Обновляем лампу во всех списках
        newState.allLights = updateLightInArray(newState.allLights, with: light)
        newState.assignedLights = updateLightInArray(newState.assignedLights, with: light)
        newState.searchResults = updateLightInArray(newState.searchResults, with: light)
        
        // Обновляем выбранную лампу если это она
        if newState.selectedLight?.id == light.id {
            newState.selectedLight = light
        }
        
    case .lightUpdateFailed(_, let error):
        newState.error = error
        newState.isLoading = false
        
    case .addToEnvironment(let id, _, _):
        // Переносим лампу из доступных в назначенные
        if let light = newState.allLights.first(where: { $0.id == id }) {
            newState.assignedLights.append(light)
        }
        
    case .removeFromEnvironment(let id):
        // Убираем лампу из назначенных
        newState.assignedLights.removeAll { $0.id == id }
        
    case .setSelectedLight(let light):
        newState.selectedLight = light
        
    case .setLoading(let isLoading):
        newState.isLoading = isLoading
        
    case .setError(let error):
        newState.error = error
        
    default:
        break
    }
    
    return newState
}



// MARK: - Helper Functions
private func updateLightInArray(_ lights: [LightEntity], with updatedLight: LightEntity) -> [LightEntity] {
    return lights.map { light in
        light.id == updatedLight.id ? updatedLight : light
    }
}

// MARK: - Placeholder Reducers (будут реализованы позже)
func bridgeReducer(state: BridgeState, action: BridgeAction) -> BridgeState {
    // TODO: Implement bridge reducer
    return state
}

func sceneReducer(state: AppSceneState, action: SceneAction) -> AppSceneState {
    // TODO: Implement scene reducer
    return state
}

func groupReducer(state: AppGroupState, action: GroupAction) -> AppGroupState {
    // TODO: Implement group reducer
    return state
}

func sensorReducer(state: SensorState, action: SensorAction) -> SensorState {
    // TODO: Implement sensor reducer
    return state
}

func ruleReducer(state: RuleState, action: RuleAction) -> RuleState {
    // TODO: Implement rule reducer
    return state
}

func uiReducer(state: UIState, action: UIAction) -> UIState {
    var newState = state
    
    switch action {
    case .setAppActive(let isActive):
        newState.isAppActive = isActive
        
    case .setShowSetup(let showSetup):
        newState.showSetup = showSetup
        
    case .setSelectedTab(let tab):
        newState.selectedTab = tab
        
    case .updatePerformanceMetrics(let metrics):
        newState.performanceMetrics = metrics
        
    case .incrementEventsReceived:
        newState.performanceMetrics.eventsReceived += 1
        
    case .incrementAPICallsCount:
        newState.performanceMetrics.apiCallsCount += 1
    }
    
    return newState
}
