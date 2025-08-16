//
//  LightsViewModel+SerialNumber.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//


import Foundation
import Combine

extension LightsViewModel {
    
    // MARK: - Serial Number Search
    
    /// Поиск лампы по серийному номеру
    func addLightBySerialNumber(_ serialNumber: String) {
        print("🔍 Поиск лампы по серийному номеру: \(serialNumber)")
        
        guard isValidSerialNumber(serialNumber) else {
            print("❌ Неверный формат серийного номера")
            error = HueAPIError.unknown("Серийный номер должен содержать 6 символов (0-9, A-Z)")
            return
        }
        
        isLoading = true
        error = nil
        clearSerialNumberFoundLights()
        
        apiClient.addLightBySerialNumber(serialNumber)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        print("❌ Ошибка добавления лампы: \(error)")
                        self?.handleSerialNumberError(error, serialNumber: serialNumber)
                    }
                },
                receiveValue: { [weak self] foundLights in
                    guard let self = self else { return }
                    
                    if !foundLights.isEmpty {
                        print("✅ Найдено ламп: \(foundLights.count)")
                        
                        self.serialNumberFoundLights = foundLights
                        
                        for light in foundLights {
                            if !self.lights.contains(where: { $0.id == light.id }) {
                                self.lights.append(light)
                                print("   + Добавлена лампа: \(light.metadata.name)")
                            }
                        }
                    } else {
                        print("❌ Лампы с серийным номером \(serialNumber) не найдены")
                        self.showNotFoundError(for: serialNumber)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Добавляет найденную лампу в список
    func addFoundLight(_ light: Light) {
        print("💡 Добавляем найденную лампу: \(light.metadata.name)")
        
        if !lights.contains(where: { $0.id == light.id }) {
            lights.append(light)
            print("✅ Лампа добавлена в список найденных ламп")
        } else {
            print("⚠️ Лампа с таким ID уже существует в списке")
        }
    }
    
    /// Добавляет лампу найденную по серийному номеру в отдельный список
    func addSerialNumberFoundLight(_ light: Light) {
        print("🔍 Добавляем лампу найденную по серийному номеру: \(light.metadata.name)")
        serialNumberFoundLights = [light]
        print("✅ Лампа по серийному номеру добавлена")
    }
    
    /// Очищает список ламп найденных по серийному номеру
    func clearSerialNumberFoundLights() {
        serialNumberFoundLights = []
    }
    
    /// Валидирует серийный номер Philips Hue
    func isValidSerialNumber(_ serialNumber: String) -> Bool {
        let cleanSerial = serialNumber
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
        
        let validCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        
        let isValidLength = cleanSerial.count == 6
        let hasOnlyValidChars = cleanSerial.rangeOfCharacter(from: validCharacterSet.inverted) == nil
        
        if !isValidLength || !hasOnlyValidChars {
            print("❌ Серийный номер '\(serialNumber)' не прошел валидацию:")
            print("   Очищенный: '\(cleanSerial)'")
            print("   Длина: \(cleanSerial.count) (ожидается 6)")
            print("   Валидные символы: \(hasOnlyValidChars)")
            return false
        }
        
        print("✅ Серийный номер '\(cleanSerial)' валиден")
        return true
    }
    
    /// Создает новый Light объект на основе серийного номера
    static func createLightFromSerialNumber(_ serialNumber: String) -> Light {
        let cleanSerialNumber = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let lightId = "light_\(cleanSerialNumber)"
        let lightName = "Hue Bulb \(cleanSerialNumber)"
        
        return Light(
            id: lightId,
            type: "light",
            metadata: LightMetadata(
                name: lightName,
                archetype: "desk_lamp"
            ),
            on: OnState(on: false),
            dimming: Dimming(brightness: 100),
            color: HueColor(
                xy: XYColor(x: 0.3, y: 0.3),
                gamut: Gamut(
                    red: XYColor(x: 0.7, y: 0.3),
                    green: XYColor(x: 0.17, y: 0.7),
                    blue: XYColor(x: 0.15, y: 0.06)
                ),
                gamut_type: "C"
            )
        )
    }
    
    // MARK: - Private Methods
    
    /// Поиск среди существующих ламп по серийному номеру
    private func findExistingLightBySerial(_ serialNumber: String) -> Light? {
        let cleanSerial = serialNumber.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        print("🔍 Ищем лампу с серийным номером: \(cleanSerial)")
        
        return lights.first { light in
            let lightId = light.id.uppercased().replacingOccurrences(of: "-", with: "")
            let lightName = light.metadata.name.uppercased()
            
            let idContainsSerial = lightId.contains(cleanSerial)
            let nameContainsSerial = lightName.contains(cleanSerial)
            let idEndsWithSerial = lightId.count >= 6 && lightId.suffix(6) == cleanSerial
            
            if idContainsSerial || nameContainsSerial || idEndsWithSerial {
                print("✅ Найдена лампа: \(light.metadata.name)")
                return true
            }
            
            return false
        }
    }
    
    /// Добавление НОВОЙ лампы по серийному номеру
    private func addNewLightBySerial(_ serialNumber: String) {
        print("🆕 Попытка добавить новую лампу: \(serialNumber)")
        
        apiClient.addLightModern(serialNumber: serialNumber)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        print("❌ Ошибка добавления: \(error)")
                        
                        self?.error = HueAPIError.unknown(
                            "Лампа с серийным номером \(serialNumber) не найдена.\n\n" +
                            "Убедитесь что:\n" +
                            "• Лампа включена и находится рядом с мостом\n" +
                            "• Серийный номер введен правильно\n" +
                            "• Лампа совместима с Philips Hue"
                        )
                        self?.serialNumberFoundLights = []
                    }
                },
                receiveValue: { [weak self] foundLights in
                    guard let self = self else { return }
                    
                    if !foundLights.isEmpty {
                        print("✅ Найдено новых ламп: \(foundLights.count)")
                        self.serialNumberFoundLights = foundLights
                        
                        let newLights = foundLights.filter { newLight in
                            !self.lights.contains { $0.id == newLight.id }
                        }
                        self.lights.append(contentsOf: newLights)
                        
                        if let firstLight = foundLights.first {
                            NavigationManager.shared.showCategoriesSelection(for: firstLight)
                        }
                    } else {
                        print("❌ Новые лампы не найдены")
                        self.error = HueAPIError.unknown("Лампа не найдена")
                        self.serialNumberFoundLights = []
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Fallback поиск по имени если API v1 недоступен
    private func searchByNameFallback(_ serialNumber: String) {
        let foundLights = lights.filter { light in
            let lightName = light.metadata.name.lowercased()
            let serialLower = serialNumber.lowercased()
            
            return lightName.contains(serialLower) ||
                   light.metadata.name.uppercased().contains(serialNumber.uppercased())
        }
        
        if !foundLights.isEmpty {
            print("✅ Найдена лампа среди подключенных: \(foundLights.first?.metadata.name ?? "")")
            serialNumberFoundLights = foundLights
            isLoading = false
        } else {
            print("❌ Лампа с серийным номером \(serialNumber) не найдена")
            print("💡 Доступные серийные номера подключенных ламп:")
            
            for light in lights {
                print("   📱 '\(light.metadata.name)' - возможные серийные номера из данных")
            }
            
            isLoading = false
            error = HueAPIError.unknown("Лампа с серийным номером \(serialNumber) не найдена среди подключенных устройств")
            serialNumberFoundLights = []
        }
    }
    
    /// Обработка ошибок при поиске по серийному номеру
    private func handleSerialNumberError(_ error: Error, serialNumber: String) {
        if let hueError = error as? HueAPIError {
            switch hueError {
            case .notAuthenticated:
                self.error = HueAPIError.unknown(
                    "Требуется авторизация. Переподключитесь к мосту."
                )
                
            case .bridgeNotFound:
                self.error = HueAPIError.unknown(
                    "Мост Hue не найден в сети. Проверьте подключение."
                )
                
            case .networkError:
                self.error = HueAPIError.unknown(
                    "Ошибка сети. Проверьте подключение к той же Wi-Fi сети, что и мост."
                )
                
            case .httpError(let statusCode):
                if statusCode == 404 {
                    showNotFoundError(for: serialNumber)
                } else {
                    self.error = HueAPIError.unknown(
                        "Ошибка HTTP \(statusCode). Попробуйте позже."
                    )
                }
                
            default:
                self.error = hueError
            }
        } else {
            self.error = HueAPIError.unknown(
                "Неизвестная ошибка: \(error.localizedDescription)"
            )
        }
        
        serialNumberFoundLights = []
    }
    
    /// Показывает понятную ошибку когда лампа не найдена
    private func showNotFoundError(for serialNumber: String) {
        self.error = HueAPIError.unknown(
            """
            Лампа с серийным номером \(serialNumber) не найдена.
            
            Проверьте:
            • Лампа включена и находится в пределах 1 метра от моста
            • Серийный номер введен правильно (6 символов)
            • Лампа совместима с Philips Hue
            • Лампа не подключена к другому мосту
            
            Если лампа была подключена к другому мосту:
            1. Выключите и включите лампу 5 раз подряд
            2. Лампа мигнет, подтверждая сброс
            3. Попробуйте добавить снова
            """
        )
    }
    
    /// Сброс лампы (для подготовки к добавлению)
    func resetLightForAddition(completion: @escaping (Bool) -> Void) {
        print("💡 Инструкция по сбросу лампы:")
        print("1. Выключите лампу")
        print("2. Включите лампу на 3 секунды")
        print("3. Выключите на 3 секунды")
        print("4. Повторите шаги 2-3 еще 4 раза")
        print("5. Включите лампу - она должна мигнуть")
        print("6. Лампа готова к добавлению")
        
        self.error = HueAPIError.unknown(
            """
            Для сброса лампы:
            
            1. Выключите лампу
            2. Включите на 3 секунды
            3. Выключите на 3 секунды
            4. Повторите шаги 2-3 еще 4 раза
            5. Включите лампу - она мигнет
            
            После сброса попробуйте добавить лампу снова.
            """
        )
        
        completion(true)
    }
    
    // MARK: - Dynamic Serial Number Mappings
    
    /// Ключ для UserDefaults
    private var mappingsKey: String { "HueLightSerialMappings" }
    
    /// Загружает сохраненные маппинги
    func loadSerialMappings() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mappingsKey) as? [String: String] ?? [:]
    }
    
    /// Сохраняет маппинг серийный номер -> ID лампы
    func saveSerialMapping(serial: String, lightId: String) {
        var mappings = loadSerialMappings()
        let cleanSerial = serial.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        mappings[cleanSerial] = lightId
        UserDefaults.standard.set(mappings, forKey: mappingsKey)
        
        print("💾 Сохранен маппинг: \(cleanSerial) -> \(lightId)")
    }
    
    /// Находит лампу по сохраненному маппингу
    func findLightByMapping(_ serial: String) -> Light? {
        let cleanSerial = serial.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        let mappings = loadSerialMappings()
        
        if let lightId = mappings[cleanSerial] {
            return lights.first { $0.id == lightId }
        }
        
        return nil
    }
    
    /// Очищает все сохраненные маппинги
    func clearSerialMappings() {
        UserDefaults.standard.removeObject(forKey: mappingsKey)
        print("🗑 Маппинги очищены")
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ LightsViewModel+SerialNumber.swift
 
 Описание:
 Расширение LightsViewModel для работы с серийными номерами ламп.
 Содержит методы поиска, добавления и валидации ламп по серийному номеру.
 
 Основные компоненты:
 - Поиск ламп по серийному номеру
 - Валидация серийных номеров (6 символов A-Z, 0-9)
 - Управление маппингами серийный номер -> ID
 - Обработка ошибок при поиске
 - Инструкции по сбросу ламп
 
 Использование:
 viewModel.addLightBySerialNumber("ABC123")
 viewModel.isValidSerialNumber("XYZ789")
 viewModel.resetLightForAddition { success in ... }
 
 Зависимости:
 - Использует internal свойства из основного класса
 - Требует HueAPIClient для поиска ламп
 - UserDefaults для хранения маппингов
 */
