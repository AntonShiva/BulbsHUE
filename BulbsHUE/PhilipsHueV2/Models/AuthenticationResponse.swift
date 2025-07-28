//
//  AuthenticationResponse.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI

/// Ответ при создании пользователя
struct AuthenticationResponse: Codable {
    /// Успешный результат
    var success: AuthSuccess?
    
    /// Ошибка
    var error: AuthError?
}

/// Успешная авторизация
struct AuthSuccess: Codable {
    /// Application key (username)
    var username: String?
    
    /// Client key для расширенной авторизации
    var clientkey: String?
}

/// Ошибка авторизации
struct AuthError: Codable {
    /// Тип ошибки
    var type: Int?
    
    /// Адрес ошибки
    var address: String?
    
    /// Описание ошибки
    var description: String?
}
