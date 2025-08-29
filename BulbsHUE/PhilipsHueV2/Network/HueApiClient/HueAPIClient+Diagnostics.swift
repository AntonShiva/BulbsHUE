//
//  HueAPIClient+Diagnostics.swift
//  BulbsHUE
//
//  Диагностические методы для отладки проблем с поиском ламп
//

import Foundation
import Combine

extension HueAPIClient {
    
    /// Диагностический метод для отладки проблем с поиском ламп
    /// Выводит детальную информацию о состоянии моста и ламп
    func runLightSearchDiagnostics() -> AnyPublisher<String, Error> {
        guard let applicationKey = applicationKey else {
            return Fail(error: HueAPIError.notAuthenticated).eraseToAnyPublisher()
        }
        
        var diagnosticInfo = "🔍 ДИАГНОСТИКА ПОИСКА ЛАМП PHILIPS HUE\n"
        diagnosticInfo += "=====================================\n\n"
        
        // 1. Информация о подключении
        diagnosticInfo += "📡 ИНФОРМАЦИЯ О ПОДКЛЮЧЕНИИ:\n"
        diagnosticInfo += "  • IP адрес моста: \(bridgeIP)\n"
        diagnosticInfo += "  • Application Key: \(String(applicationKey.prefix(10)))...\n"
        diagnosticInfo += "  • Дата/время: \(Date())\n\n"
        
        // 2. Проверка всех ламп через v2 API
        return getAllLightsV2HTTPS()
            .flatMap { [weak self] v2Lights -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Just(diagnosticInfo).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                diagnosticInfo += "💡 ЛАМПЫ V2 API (HTTPS):\n"
                diagnosticInfo += "  • Всего найдено: \(v2Lights.count)\n"
                
                if !v2Lights.isEmpty {
                    diagnosticInfo += "  • Список:\n"
                    for (index, light) in v2Lights.enumerated() {
                        let reachable = light.isReachable ? "✅" : "❌"
                        diagnosticInfo += "    \(index + 1). \"\(light.metadata.name)\" \(reachable)\n"
                        diagnosticInfo += "       - ID: \(light.id)\n"
                        diagnosticInfo += "       - Тип: \(light.metadata.archetype ?? "unknown")\n"
                    }
                }
                diagnosticInfo += "\n"
                
                // 3. Завершение диагностики (убрана проверка v1 API)
                diagnosticInfo += "🔍 ДИАГНОСТИКА ЗАВЕРШЕНА\n"
                diagnosticInfo += "  • API v2 HTTPS проверен\n"
                diagnosticInfo += "  • Лампы загружены успешно\n"
                diagnosticInfo += "\n"
                
                // 4. Анализ проблем и рекомендации (упрощено)
                diagnosticInfo += self.generateRecommendations(
                    v2Count: v2Lights.count,
                    v1Count: 0, // v1 API больше не используется
                    newIds: [], // Больше не проверяем статус поиска
                    zigbeeCount: 0
                )
                
                return Just(diagnosticInfo)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Генерирует рекомендации на основе диагностики
    private func generateRecommendations(v2Count: Int, v1Count: Int, newIds: [String], zigbeeCount: Int) -> String {
        var recommendations = "💡 АНАЛИЗ И РЕКОМЕНДАЦИИ:\n"
        recommendations += "========================\n\n"
        
        // Проблема: нет ламп вообще
        if v2Count == 0 && v1Count == 0 {
            recommendations += "⚠️ ПРОБЛЕМА: В системе нет ни одной лампы!\n\n"
            recommendations += "ВОЗМОЖНЫЕ ПРИЧИНЫ:\n"
            recommendations += "1. Лампы не были добавлены к мосту\n"
            recommendations += "2. Мост был сброшен к заводским настройкам\n"
            recommendations += "3. Проблема с Zigbee сетью\n\n"
            recommendations += "РЕКОМЕНДАЦИИ:\n"
            recommendations += "• Убедитесь, что лампы включены в розетку\n"
            recommendations += "• Попробуйте сбросить лампу (включить/выключить 5 раз)\n"
            recommendations += "• Проверьте индикатор на мосте (должен гореть синим)\n"
            recommendations += "• Используйте функцию Touchlink (поднесите лампу к мосту)\n"
        }
        // Проблема: есть лампы, но новые не находятся
        else if newIds.isEmpty && v2Count > 0 {
            recommendations += "⚠️ ПРОБЛЕМА: Новые лампы не обнаруживаются\n\n"
            recommendations += "ТЕКУЩЕЕ СОСТОЯНИЕ:\n"
            recommendations += "• В системе уже есть \(v2Count) ламп(ы)\n"
            recommendations += "• Новые лампы не найдены при последнем поиске\n\n"
            recommendations += "РЕКОМЕНДАЦИИ ДЛЯ КАНАДЫ И ДРУГИХ РЕГИОНОВ:\n"
            recommendations += "1. СБРОС ЛАМПЫ:\n"
            recommendations += "   • Включите лампу\n"
            recommendations += "   • Выключите и включите 5 раз подряд (интервал ~1 сек)\n"
            recommendations += "   • Лампа должна мигнуть, подтверждая сброс\n\n"
            recommendations += "2. ПРОВЕРКА СОВМЕСТИМОСТИ:\n"
            recommendations += "   • Убедитесь, что лампа поддерживает Zigbee\n"
            recommendations += "   • Проверьте, что лампа из списка \"Friends of Hue\"\n"
            recommendations += "   • Некоторые региональные модели могут не поддерживаться\n\n"
            recommendations += "3. ZIGBEE КАНАЛ:\n"
            recommendations += "   • В приложении Hue: Настройки → Мост → Смена канала Zigbee\n"
            recommendations += "   • Попробуйте каналы 11, 15, 20, 25 (наименее загруженные)\n"
            recommendations += "   • Wi-Fi 2.4GHz может создавать помехи\n\n"
            recommendations += "4. РАССТОЯНИЕ:\n"
            recommendations += "   • Поднесите лампу ближе к мосту (< 10 метров)\n"
            recommendations += "   • Уберите металлические предметы между лампой и мостом\n"
            recommendations += "   • Другие Zigbee устройства помогают расширить сеть\n"
        }
        // Несоответствие между v1 и v2 API
        else if abs(v2Count - v1Count) > 1 {
            recommendations += "⚠️ ВНИМАНИЕ: Несоответствие данных между API!\n"
            recommendations += "• V2 API показывает: \(v2Count) ламп\n"
            recommendations += "• V1 API показывает: \(v1Count) ламп\n\n"
            recommendations += "РЕКОМЕНДАЦИИ:\n"
            recommendations += "• Перезагрузите мост Hue\n"
            recommendations += "• Подождите 2-3 минуты после перезагрузки\n"
        }
        // Все хорошо
        else if !newIds.isEmpty {
            recommendations += "✅ УСПЕХ: Найдены новые лампы!\n"
            recommendations += "• ID новых ламп: \(newIds.joined(separator: ", "))\n"
            recommendations += "• Теперь их можно настроить и использовать\n"
        }
        
        recommendations += "\n📱 ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ:\n"
        recommendations += "• Версия моста: проверьте в настройках приложения\n"
        recommendations += "• Обновления: убедитесь, что мост обновлен\n"
        recommendations += "• Поддержка: https://www.philips-hue.com/support\n"
        
        return recommendations
    }
    
}
