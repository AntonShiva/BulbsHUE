//
//  AppViewModel+Keychain.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/15/25.
//

import Foundation
import Combine

// MARK: - Keychain Management

extension AppViewModel {
    
    /// Загружает сохраненные настройки из Keychain
    func loadSavedSettingsFromKeychain() {
        if let credentials = HueKeychainManager.shared.getLastBridgeCredentials() {
            applicationKey = credentials.applicationKey
            recreateAPIClient(with: credentials.bridgeIP)
            
            if let clientKey = credentials.clientKey {
                setupEntertainmentClient(clientKey: clientKey)
            }
            
            currentBridge = Bridge(
                id: credentials.bridgeId,
                internalipaddress: credentials.bridgeIP,
                port: 443
            )
            
            connectionStatus = .connected
            showSetup = false  // 🔧 ИСПРАВЛЕНИЕ: Переходим к главному экрану при загрузке сохраненных данных
            startEventStream()
        } else {
            showSetup = true
        }
    }
    
    /// Сохраняет учетные данные при успешном подключении
    func saveCredentials() {
        guard let bridge = currentBridge,
              let appKey = applicationKey else { return }
        
        let clientKey = HueKeychainManager.shared.getClientKey(for: bridge.id)
        
        let credentials = HueKeychainManager.BridgeCredentials(
            bridgeId: bridge.id,
            bridgeIP: bridge.internalipaddress,
            applicationKey: appKey,
            clientKey: clientKey
        )
        
        _ = HueKeychainManager.shared.saveBridgeCredentials(credentials)
    }
    
    /// Отключается от моста и удаляет сохраненные данные
    func disconnectAndClearData() {
        guard let bridge = currentBridge else { return }
        
        disconnect()
        HueKeychainManager.shared.deleteCredentials(for: bridge.id)
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ AppViewModel+Keychain.swift
 
 Описание:
 Расширение AppViewModel для работы с безопасным хранилищем Keychain.
 Управляет сохранением и загрузкой учетных данных для подключения к Hue Bridge.
 
 Основные компоненты:
 - loadSavedSettingsFromKeychain() - загрузка сохраненных credentials
 - saveCredentials() - сохранение текущих учетных данных
 - disconnectAndClearData() - отключение и удаление всех данных
 
 Использование:
 appViewModel.loadSavedSettingsFromKeychain()
 appViewModel.saveCredentials()
 appViewModel.disconnectAndClearData()
 
 Безопасность:
 - Application key и client key хранятся в Keychain
 - Автоматическое восстановление подключения при запуске
 - Полное удаление данных при отключении
 
 Зависимости:
 - HueKeychainManager для работы с Keychain
 - BridgeCredentials структура для хранения данных
 
 Связанные файлы:
 - AppViewModel.swift - основной класс
 - HueKeychainManager.swift - менеджер Keychain
 - AppViewModel+Connection.swift - методы подключения
 */
