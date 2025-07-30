//
//  HueKeychainManager.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 30.07.2025.
//

//
//  HueKeychainManager.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Security

/// Менеджер для безопасного хранения учетных данных Hue
class HueKeychainManager {
    
    static let shared = HueKeychainManager()
    
    private let service = "com.philipshue.v2"
    private let applicationKeyKey = "applicationKey"
    private let clientKeyKey = "clientKey"
    private let bridgeIdKey = "bridgeId"
    
    private init() {}
    
    // MARK: - Application Key
    
    /// Сохраняет application key в Keychain
    func saveApplicationKey(_ key: String, for bridgeId: String) -> Bool {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(applicationKeyKey)_\(bridgeId)",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Удаляем старое значение
        SecItemDelete(query as CFDictionary)
        
        // Добавляем новое
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Получает application key из Keychain
    func getApplicationKey(for bridgeId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(applicationKeyKey)_\(bridgeId)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return nil
    }
    
    // MARK: - Client Key
    
    /// Сохраняет client key для Entertainment API
    func saveClientKey(_ key: String, for bridgeId: String) -> Bool {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(clientKeyKey)_\(bridgeId)",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Получает client key из Keychain
    func getClientKey(for bridgeId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(clientKeyKey)_\(bridgeId)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return nil
    }
    
    // MARK: - Bridge Credentials
    
    /// Структура для хранения всех учетных данных моста
    struct BridgeCredentials {
        let bridgeId: String
        let bridgeIP: String
        let applicationKey: String
        let clientKey: String?
    }
    
    /// Сохраняет все учетные данные моста
    func saveBridgeCredentials(_ credentials: BridgeCredentials) -> Bool {
        // Сохраняем в UserDefaults последний использованный мост
        UserDefaults.standard.set(credentials.bridgeId, forKey: "lastUsedBridgeId")
        UserDefaults.standard.set(credentials.bridgeIP, forKey: "lastUsedBridgeIP")
        
        // Сохраняем ключи в Keychain
        let appKeySaved = saveApplicationKey(credentials.applicationKey, for: credentials.bridgeId)
        
        if let clientKey = credentials.clientKey {
            let clientKeySaved = saveClientKey(clientKey, for: credentials.bridgeId)
            return appKeySaved && clientKeySaved
        }
        
        return appKeySaved
    }
    
    /// Получает учетные данные последнего использованного моста
    func getLastBridgeCredentials() -> BridgeCredentials? {
        guard let bridgeId = UserDefaults.standard.string(forKey: "lastUsedBridgeId"),
              let bridgeIP = UserDefaults.standard.string(forKey: "lastUsedBridgeIP"),
              let applicationKey = getApplicationKey(for: bridgeId) else {
            return nil
        }
        
        let clientKey = getClientKey(for: bridgeId)
        
        return BridgeCredentials(
            bridgeId: bridgeId,
            bridgeIP: bridgeIP,
            applicationKey: applicationKey,
            clientKey: clientKey
        )
    }
    
    /// Удаляет все сохраненные учетные данные
    func deleteAllCredentials() {
        // Удаляем из UserDefaults
        UserDefaults.standard.removeObject(forKey: "lastUsedBridgeId")
        UserDefaults.standard.removeObject(forKey: "lastUsedBridgeIP")
        
        // Удаляем все из Keychain для этого сервиса
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    /// Удаляет учетные данные для конкретного моста
    func deleteCredentials(for bridgeId: String) {
        // Удаляем application key
        let appKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(applicationKeyKey)_\(bridgeId)"
        ]
        SecItemDelete(appKeyQuery as CFDictionary)
        
        // Удаляем client key
        let clientKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(clientKeyKey)_\(bridgeId)"
        ]
        SecItemDelete(clientKeyQuery as CFDictionary)
        
        // Если это был последний использованный мост, очищаем UserDefaults
        if UserDefaults.standard.string(forKey: "lastUsedBridgeId") == bridgeId {
            UserDefaults.standard.removeObject(forKey: "lastUsedBridgeId")
            UserDefaults.standard.removeObject(forKey: "lastUsedBridgeIP")
        }
    }
}
