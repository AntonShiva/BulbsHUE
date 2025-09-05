//
//  HueAPIError.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI


/// Ошибки при работе с Hue API
enum HueAPIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case linkButtonNotPressed
    case notImplemented
    case rateLimitExceeded
    case bufferFull
    case conflictingRules
    case loopDetected
    case outdatedBridge
    case localNetworkPermissionDenied
    case bridgeNotFound
    case encodingError
    case networkError(Error)
    case unknown(String)
    case invalidParameter(String)
    case endpointNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Требуется авторизация. Установите application key."
        case .invalidURL:
            return "Неверный URL адрес"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .httpError(let statusCode):
            return "HTTP ошибка: \(statusCode)"
        case .linkButtonNotPressed:
            return "Нажмите кнопку Link на Hue Bridge"
        case .notImplemented:
            return "Функция еще не реализована"
        case .rateLimitExceeded:
            return "Превышен лимит запросов. Подождите перед следующим запросом."
        case .bufferFull:
            return "Буфер моста переполнен. Снизьте частоту запросов."
        case .conflictingRules:
            return "Обнаружены конфликтующие правила. Удалите дублирующие правила."
        case .loopDetected:
            return "Обнаружен цикл в правилах. Правило не может изменять тот же сенсор, который его запускает."
        case .outdatedBridge:
            return "Мост требует обновления прошивки для поддержки API v2"
        case .localNetworkPermissionDenied:
            return "Разрешение на доступ к локальной сети отклонено. Перейдите в Настройки > Конфиденциальность и безопасность > Локальная сеть и включите разрешение для этого приложения."
        case .bridgeNotFound:
            return "Hue Bridge не найден в сети. Убедитесь что мост подключен к той же Wi-Fi сети."
        case .encodingError:
            return "Ошибка кодирования данных запроса"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .unknown(let message):
            return "Неизвестная ошибка: \(message)"
        case .invalidParameter(let message):
            return "Неверный параметр: \(message)"
        case .endpointNotFound:
            return "Endpoint не найден. Возможно, требуется более новая версия Hue Bridge."
        }
    }
}
