//
//  PerformanceGuidelines.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// Рекомендации по производительности Hue API:
///
/// Латентность системы (transitiontime=0):
/// - 1 ZigBee сообщение (только яркость): ~55мс
/// - 2 ZigBee сообщения (яркость + цвет): ~95мс
/// - 3 ZigBee сообщения (яркость + цвет + on): ~125мс
///
/// Пропускная способность:
/// - Максимум ~25 ZigBee сообщений в секунду
/// - Для lights: ~10 команд в секунду с интервалом 100мс
/// - Для groups: ~1 команда в секунду
///
/// Оптимизация:
/// - Не отправляйте параметр "on" если лампа уже включена
/// - Не отправляйте "bri" если меняется только цвет
/// - Используйте группы для синхронного изменения нескольких ламп
/// - Для длительных эффектов используйте Entertainment API
///
/// Особые случаи:
/// - При превышении лимитов команды буферизуются (увеличивается латентность)
/// - При переполнении буфера возвращается ошибка 503
/// - Групповые команды используют broadcast и ограничены 1/сек
struct PerformanceGuidelines {
    static let maxZigBeeMessagesPerSecond = 25
    static let recommendedLightCommandsPerSecond = 10
    static let lightCommandInterval: TimeInterval = 0.1
    static let groupCommandInterval: TimeInterval = 1.0
    
    static let latencyOneMessage = 55 // мс
    static let latencyTwoMessages = 95 // мс
    static let latencyThreeMessages = 125 // мс
}
