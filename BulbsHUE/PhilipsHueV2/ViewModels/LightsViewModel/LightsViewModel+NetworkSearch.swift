//
//  LightsViewModel+NetworkSearch.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/16/25.
//


import Foundation
import Combine

extension LightsViewModel {
    
    // MARK: - Network Search
    
    /// Правильный общий поиск новых ламп через Hue Bridge
    func searchForNewLights(completion: @escaping ([Light]) -> Void) {
        print("🔍 Поиск новых ламп (инициируем v1 scan)...")
        let currentLightIds = Set(lights.map { $0.id })
        isLoading = true
        networkFoundLights = []
        
        apiClient.addLightModern(serialNumber: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        print("❌ Ошибка поиска: \(error)")
                        self?.error = error
                        completion([])
                    }
                },
                receiveValue: { [weak self] allLights in
                    guard let self = self else { completion([]); return }
                    
                    let newLights = allLights.filter { !currentLightIds.contains($0.id) }
                    print("✅ Найдено новых ламп: \(newLights.count)")
                    self.lights = allLights
                    self.networkFoundLights = newLights
                    completion(newLights)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Автоматический поиск новых ламп в сети (без серийного номера)
    func searchForNewLights() {
        print("🔍 Автоматический поиск новых ламп...")
        
        isLoading = true
        error = nil
        
        let currentLightIds = Set(lights.map { $0.id })
        
        apiClient.getAllLights()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        print("❌ Ошибка поиска: \(error)")
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] allLights in
                    guard let self = self else { return }
                    
                    // В новом API-flow полагаемся на сравнение ID до/после поиска
                    let newLights = allLights.filter { light in
                        !currentLightIds.contains(light.id)
                    }
                    
                    // Дополнительно проверяем isNewLight только для edge cases
                    let potentiallyNewLights = allLights.filter { light in
                        !currentLightIds.contains(light.id) || 
                        (currentLightIds.contains(light.id) && light.isNewLight)
                    }
                    
                    let finalNewLights = !newLights.isEmpty ? newLights : potentiallyNewLights
                    
                    if !finalNewLights.isEmpty {
                        print("✅ Найдено новых ламп: \(finalNewLights.count)")
                        
                        self.lights = allLights
                        self.serialNumberFoundLights = finalNewLights
                        
                        if let firstNewLight = finalNewLights.first {
                            self.selectedLight = firstNewLight
                        }
                    } else {
                        print("ℹ️ Новые лампы не найдены")
                        self.error = HueAPIError.unknown(
                            """
                            Новые лампы не обнаружены.
                            
                            Убедитесь, что:
                            • Лампы подключены к питанию
                            • Лампы находятся рядом с мостом
                            • Лампы не подключены к другому мосту
                            """
                        )
                    }
                }
            )
            .store(in: &cancellables)
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ LightsViewModel+NetworkSearch.swift
 
 Описание:
 Расширение LightsViewModel для сетевого поиска новых ламп.
 Содержит методы автоматического обнаружения ламп в сети.
 
 Основные компоненты:
 - Поиск новых ламп через v1 scan
 - Автоматическое обнаружение в сети
 - Фильтрация уже подключенных ламп
 - Обработка результатов поиска
 
 Использование:
 viewModel.searchForNewLights { lights in ... }
 viewModel.searchForNewLights()
 
 Зависимости:
 - Использует internal свойства из основного класса
 - Требует HueAPIClient для сканирования сети
 - Обновляет networkFoundLights и serialNumberFoundLights
 */
