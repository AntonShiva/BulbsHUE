//
//  HueAPIClient+EventStream.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import Combine

extension HueAPIClient {
    
    // MARK: - Event Stream (Server-Sent Events)
    
    /// Подключается к потоку событий для получения обновлений в реальном времени
    /// Использует Server-Sent Events (SSE) для минимизации нагрузки
    /// - Returns: Combine Publisher с событиями
    func connectToEventStream() -> AnyPublisher<HueEvent, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        guard let url = baseURL?.appendingPathComponent("/eventstream/clip/v2") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = TimeInterval.infinity
        
        return Future<HueEvent, Error> { [weak self] promise in
            self?.eventStreamTask = self?.session.dataTask(with: request)
            self?.eventStreamTask?.resume()
        }
        .eraseToAnyPublisher()
    }
    
    /// Подключается к потоку событий - версия API v2
    func connectToEventStreamV2() -> AnyPublisher<HueEvent, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        // Правильный URL для SSE в API v2
        guard let url = baseURL?.appendingPathComponent("/eventstream/clip/v2") else {
            return Fail(error: HueAPIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue(applicationKey, forHTTPHeaderField: "hue-application-key")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = TimeInterval.infinity
        
        // Добавляем keep-alive
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        return Future<HueEvent, Error> { [weak self] promise in
            self?.eventStreamTask = self?.session.dataTask(with: request)
            self?.eventStreamTask?.resume()
        }
        .eraseToAnyPublisher()
    }
    
    /// Отключается от потока событий
    func disconnectEventStream() {
        eventStreamTask?.cancel()
        eventStreamTask = nil
        eventStreamBuffer = Data()
    }
    
    // MARK: - Private Methods
    
    /// Парсит событие в формате SSE
    internal func parseSSEEvent(_ data: Data) {
        eventStreamBuffer.append(data)
        
        // Конвертируем в строку для поиска событий
        guard let string = String(data: eventStreamBuffer, encoding: .utf8) else { return }
        
        // SSE события разделяются двойным переводом строки
        let events = string.components(separatedBy: "\n\n")
        
        for (index, eventString) in events.enumerated() {
            // Последний элемент может быть неполным
            if index == events.count - 1 && !eventString.isEmpty {
                // Сохраняем неполное событие в буфере
                eventStreamBuffer = eventString.data(using: .utf8) ?? Data()
                break
            }
            
            // Парсим полное событие
            if !eventString.isEmpty {
                parseSSEEventString(eventString)
            }
        }
        
        // Если обработали все события, очищаем буфер
        if events.last?.isEmpty == true {
            eventStreamBuffer = Data()
        }
    }
    
    /// Парсит строку события SSE
    internal func parseSSEEventString(_ eventString: String) {
        let lines = eventString.components(separatedBy: "\n")
        var eventType: String?
        var eventData: String?
        var eventId: String?
        
        for line in lines {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7))
            } else if line.hasPrefix("data: ") {
                eventData = String(line.dropFirst(6))
            } else if line.hasPrefix("id: ") {
                eventId = String(line.dropFirst(4))
            }
        }
        
        // Парсим JSON данные события
        guard let eventData = eventData,
              let data = eventData.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let events = try decoder.decode([HueEvent].self, from: data)
            
            for event in events {
                eventSubject.send(event)
            }
        } catch {
            print("Error parsing SSE event: \(error)")
        }
    }
}

/*
 ДОКУМЕНТАЦИЯ К ФАЙЛУ HueAPIClient+EventStream.swift
 
 Описание:
 Расширение HueAPIClient для работы с Server-Sent Events (SSE).
 Обеспечивает получение обновлений в реальном времени.
 
 Основные компоненты:
 - connectToEventStream - подключение к потоку событий
 - connectToEventStreamV2 - версия для API v2
 - disconnectEventStream - отключение от потока
 - parseSSEEvent - парсинг SSE событий
 - parseSSEEventString - парсинг строки события
 
 Особенности:
 - Использует бесконечный timeout для поддержания соединения
 - Буферизация данных для обработки неполных событий
 - Автоматический парсинг JSON событий
 
 Зависимости:
 - HueAPIClient базовый класс
 - HueEvent модель
 - eventSubject для публикации событий
 
 Связанные файлы:
 - HueAPIClient.swift - базовый класс
 - HueAPIClient+URLSessionDelegate.swift - обработка делегата
 */
