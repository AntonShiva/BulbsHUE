//
//  BatchModels.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 31.07.2025.
//

import SwiftUI

// MARK: - Batch Operation Models for API v2

/// Batch запрос для множественных операций
struct BatchRequest: Codable {
    let data: [BatchUpdate]
}

/// Batch обновление для одного ресурса
struct BatchUpdate: Codable {
    let rid: String          // Resource ID
    let rtype: String        // Resource type (light, group, etc.)
    let on: OnState?
    let dimming: Dimming?
    let color: HueColor?
    let color_temperature: ColorTemperature?
    let effects_v2: EffectsV2?
    let gradient: GradientState?
}

/// Batch ответ от API
struct BatchResponse: Codable {
    let errors: [APIError]?
    let data: [BatchUpdateResult]?
}

/// Результат batch обновления одного ресурса
struct BatchUpdateResult: Codable {
    let rid: String     // Resource ID
    let rtype: String   // Resource type
}
