//
//  LightEntity.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation

// MARK: - Domain Entity для лампы
/// Чистая доменная модель лампы без зависимостей от фреймворков
struct LightEntity: Equatable, Identifiable {
    let id: String
    let name: String
    let type: LightType
    let subtype: LightSubtype?
    let isOn: Bool
    let brightness: Double // 0.0 - 100.0
    let color: LightColor?
    let colorTemperature: Int?
    let isReachable: Bool
    let roomId: String? // ID комнаты, в которой находится лампа
    let userSubtype: String?
    let userIcon: String?
}

// MARK: - Light Types (физические типы ламп)
enum LightType: String, CaseIterable {
    case table = "TABLE"
    case floor = "FLOOR"
    case wall = "WALL"
    case ceiling = "CEILING"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .table: return "Table"
        case .floor: return "Floor"
        case .wall: return "Wall"
        case .ceiling: return "Ceiling"
        case .other: return "Other"
        }
    }
}

// MARK: - Light Subtypes (подтипы ламп)
enum LightSubtype: String, CaseIterable {
    // Table subtypes
    case traditionalLamp = "TRADITIONAL_LAMP"
    case deskLamp = "DESK_LAMP"
    case tableWash = "TABLE_WASH"
    
    // Floor subtypes
    case floor = "FLOOR"
    case christmasTree = "CHRISTMAS_TREE"
    case floorShade = "FLOOR_SHADE"
    case floorLantern = "FLOOR_LANTERN"
    case bollard = "BOLLARD"
    case groundSpot = "GROUND_SPOT"
    case recessedFloor = "RECESSED_FLOOR"
    case lightBar = "LIGHT_BAR"
    
    // Wall subtypes
    case wallLantern = "WALL_LANTERN"
    case wallShade = "WALL_SHADE"
    case wallSpot = "WALL_SPOT"
    case dualWallLight = "DUAL_WALL_LIGHT"
    
    // Ceiling subtypes
    case pendantSound = "PENDANT_SOUND"
    case pendantHorizontal = "PENDANT_HORIZONTAL"
    case ceilingRound = "CEILING_ROUND"
    case ceilingSquare = "CEILING_SQUARE"
    case singleSpot = "SINGLE_SPOT"
    case doubleSpot = "DOUBLE_SPOT"
    case recessedCeiling = "RECESSED_CEILING"
    case pedantSpot = "PEDANT_SPOT"
    case ceilingHorizontal = "CEILING_HORIZONTAL"
    case ceilingTube = "CEILING_TUBE"
    
    // Other subtypes
    case signatureBulb = "SIGNATURE_BULB"
    case roundedBulb = "ROUNDED_BULB"
    case spot = "SPOT"
    case floodLight = "FLOOD_LIGHT"
    case candelabraBulb = "CANDELABRA_BULB"
    case filamentBulb = "FILAMENT_BULB"
    case miniBulb = "MINI_BULB"
    case hueLightstrip = "HUE_LIGHTSTRIP"
    case lightguide = "LIGHTGUIDE"
    case playLightBar = "PLAY_LIGHT_BAR"
    case hueBloom = "HUE_BLOOM"
    case hueIris = "HUE_IRIS"
    case smartPlug = "SMART_PLUG"
    case hueCentris = "HUE_CENTRIS"
    case hueTube = "HUE_TUBE"
    case hueSign = "HUE_SIGN"
    case floodlightCamera = "FLOODLIGHT_CAMERA"
    case twilight = "TWILIGHT"
    
    var displayName: String {
        switch self {
        // Table
        case .traditionalLamp: return "Traditional Lamp"
        case .deskLamp: return "Desk Lamp"
        case .tableWash: return "Table Wash"
        
        // Floor
        case .floor: return "Floor"
        case .christmasTree: return "Christmas Tree"
        case .floorShade: return "Floor Shade"
        case .floorLantern: return "Floor Lantern"
        case .bollard: return "Bollard"
        case .groundSpot: return "Ground Spot"
        case .recessedFloor: return "Recessed Floor"
        case .lightBar: return "Light Bar"
        
        // Wall
        case .wallLantern: return "Wall Lantern"
        case .wallShade: return "Wall Shade"
        case .wallSpot: return "Wall Spot"
        case .dualWallLight: return "Dual Wall Light"
        
        // Ceiling
        case .pendantSound: return "Pendant Sound"
        case .pendantHorizontal: return "Pendant Horizontal"
        case .ceilingRound: return "Ceiling Round"
        case .ceilingSquare: return "Ceiling Square"
        case .singleSpot: return "Single Spot"
        case .doubleSpot: return "Double Spot"
        case .recessedCeiling: return "Recessed Ceiling"
        case .pedantSpot: return "Pedant Spot"
        case .ceilingHorizontal: return "Ceiling Horizontal"
        case .ceilingTube: return "Ceiling Tube"
        
        // Other
        case .signatureBulb: return "Signature Bulb"
        case .roundedBulb: return "Rounded Bulb"
        case .spot: return "Spot"
        case .floodLight: return "Flood Light"
        case .candelabraBulb: return "Candelabra Bulb"
        case .filamentBulb: return "Filament Bulb"
        case .miniBulb: return "Mini-Bulb"
        case .hueLightstrip: return "Hue Lightstrip"
        case .lightguide: return "Lightguide"
        case .playLightBar: return "Play Light Bar"
        case .hueBloom: return "Hue Bloom"
        case .hueIris: return "Hue Iris"
        case .smartPlug: return "Smart Plug"
        case .hueCentris: return "Hue Centris"
        case .hueTube: return "Hue Tube"
        case .hueSign: return "Hue Signe"
        case .floodlightCamera: return "Floodlight Camera"
        case .twilight: return "Twilight"
        }
    }
    
    var parentType: LightType {
        switch self {
        case .traditionalLamp, .deskLamp, .tableWash:
            return .table
        case .floor, .christmasTree, .floorShade, .floorLantern, .bollard, .groundSpot, .recessedFloor, .lightBar:
            return .floor
        case .wallLantern, .wallShade, .wallSpot, .dualWallLight:
            return .wall
        case .pendantSound, .pendantHorizontal, .ceilingRound, .ceilingSquare, .singleSpot, .doubleSpot, .recessedCeiling, .pedantSpot, .ceilingHorizontal, .ceilingTube:
            return .ceiling
        case .signatureBulb, .roundedBulb, .spot, .floodLight, .candelabraBulb, .filamentBulb, .miniBulb, .hueLightstrip, .lightguide, .playLightBar, .hueBloom, .hueIris, .smartPlug, .hueCentris, .hueTube, .hueSign, .floodlightCamera, .twilight:
            return .other
        }
    }
}






// MARK: - Вспомогательные структуры
struct LightColor: Equatable {
    let x: Double
    let y: Double
}

// MARK: - Computed Properties
extension LightEntity {
    /// Эффективное состояние лампы с учетом доступности
    var effectiveState: EffectiveLightState {
        if !isReachable {
            return EffectiveLightState(isOn: false, brightness: 0.0, isReachable: false)
        }
        return EffectiveLightState(isOn: isOn, brightness: brightness, isReachable: true)
    }
    
    /// Есть ли цветовая поддержка
    var supportsColor: Bool {
        return color != nil
    }
    
    /// Есть ли поддержка цветовой температуры
    var supportsColorTemperature: Bool {
        return colorTemperature != nil
    }
}

struct EffectiveLightState: Equatable {
    let isOn: Bool
    let brightness: Double
    let isReachable: Bool
}
