//
//  ColorPickerTabsViewModel.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 9/05/25.
//

import SwiftUI
import Combine

@MainActor
class ColorPickerTabsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedTab: ColorPickerTab = .hexPicker
    @Published var selectedColor: Color = .orange
    @Published var selectedColorRelativePosition: CGPoint = CGPoint(x: 0.63, y: 0.9) // Относительные координаты от 0 до 1
    @Published var brightness: Double = 24.0
    @Published var warmColdLamps: [WarmColdLamp] = []
    @Published var palletColors: [PalletColorItem] = []
    @Published var selectedPalletColorItem: PalletColorItem?
    
    // MARK: - Warm/Cold Properties
    @Published var warmColdSelectedColor: Color = Color(red: 1.0, green: 0.9, blue: 0.8) // Нейтральный белый по умолчанию
    @Published var warmColdRelativePosition: CGPoint = CGPoint(x: 0.5, y: 0.5) // Позиция в warm/cold круге
    
    // MARK: - Room Light Markers for HEX Picker
    @Published var roomLightMarkers: [RoomLightMarker] = []
    
    #if canImport(UIKit)
    @Published var pickerImage: UIImage? = nil
    #endif
    
    // MARK: - Computed Properties
    
    /// Определяем, настраиваем ли одну лампу или комнату
    var isTargetingSingleLight: Bool {
        return NavigationManager.shared.targetLightForColorChange != nil
    }
    
    // MARK: - Initialization
    
    init() {
        setupWarmColdLamps()
        setupPalletColors()
        setupRoomLightMarkers()
        
        // Загружаем изображение для получения реальных цветов
        #if canImport(UIKit)
        pickerImage = UIImage(named: "ColorCircl")
        #endif
        
        // ✅ ИСПРАВЛЕНИЕ: Инициализируем с сохраненным состоянием для текущей целевой лампы
        initializeWithSavedState()
        
        // Устанавливаем правильный цвет указателя при старте
        updateSelectedColorFromCurrentPosition()
    }
    
    /// Инициализирует ViewModel с сохраненным состоянием для текущей целевой лампы
    private func initializeWithSavedState() {
        // Получаем целевую лампу из NavigationManager
        let targetLightId: String?
        
        if let targetLight = NavigationManager.shared.targetLightForColorChange {
            targetLightId = targetLight.id
        } else if let targetRoom = NavigationManager.shared.targetRoomForColorChange {
            // Для комнаты берем первую лампу как представительную
            targetLightId = targetRoom.lightIds.first
        } else {
            targetLightId = nil
        }
        
        guard let lightId = targetLightId else { return }
        
        // Восстанавливаем сохраненный цвет и позицию для hex picker
        if let savedColor = LightColorStateService.shared.getLightColor(lightId) {
            selectedColor = savedColor
            print("🔄 Восстановлен цвет для лампы \(lightId)")
        }
        
        if let savedPosition = LightColorStateService.shared.getColorPickerPosition(lightId) {
            selectedColorRelativePosition = savedPosition
            print("🔄 Восстановлена позиция color picker для лампы \(lightId)")
        }
        
        // ✅ УЛУЧШЕННАЯ ЛОГИКА: Восстановление warm/cold позиции
        restoreWarmColdPosition(for: lightId)
    }
    
    /// Восстанавливает позицию указателя в warm/cold режиме на основе текущего цвета лампы
    private func restoreWarmColdPosition(for lightId: String) {
        let currentColor: Color
        
        // Получаем текущий цвет лампы (сохраненный или базовый из лампы)
        if let savedColor = LightColorStateService.shared.getLightColor(lightId) {
            currentColor = savedColor
            warmColdSelectedColor = savedColor
        } else {
            // Попробуем получить объект лампы для базового цвета
            let targetLight: Light?
            
            if let light = NavigationManager.shared.targetLightForColorChange {
                targetLight = light
            } else if let room = NavigationManager.shared.targetRoomForColorChange,
                      let firstLightId = room.lightIds.first {
                // Для комнаты нам нужно найти объект лампы по ID
                // Пока используем дефолтный цвет, так как у нас нет прямого доступа к объекту лампы по ID
                targetLight = nil
            } else {
                targetLight = nil
            }
            
            if let light = targetLight {
                let baseColor = LightColorStateService.shared.getBaseColor(for: light)
                currentColor = baseColor
                warmColdSelectedColor = baseColor
            } else {
                // Дефолтный нейтральный белый
                currentColor = Color(red: 1.0, green: 0.9, blue: 0.8)
                warmColdSelectedColor = currentColor
                warmColdRelativePosition = CGPoint(x: 0.5, y: 0.5)
                return
            }
        }
        
        // Проверяем, является ли цвет теплым/холодным (близким к температурной шкале)
        if let temperatureRatio = analyzeColorTemperature(currentColor) {
            // ✅ Цвет является теплым/холодным - показываем указатель на соответствующей позиции
            warmColdRelativePosition = CGPoint(x: temperatureRatio, y: 0.5)
            print("🌡️ Цвет лампы является температурным, позиция: \(temperatureRatio)")
        } else {
            // ✅ Цвет цветной (зеленый, синий и т.д.) - показываем указатель в центре
            warmColdRelativePosition = CGPoint(x: 0.5, y: 0.5)
            print("🎨 Цвет лампы цветной, указатель в центре")
        }
    }
    
    /// Анализирует цвет и определяет, является ли он теплым/холодным (возвращает позицию на температурной шкале)
    /// - Parameter color: Анализируемый цвет
    /// - Returns: Соотношение температуры (0.0 = теплый, 1.0 = холодный) или nil если цвет цветной
    private func analyzeColorTemperature(_ color: Color) -> Double? {
        // Конвертируем Color в RGB компоненты
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        // Проверяем, является ли цвет близким к температурной шкале
        // Температурные цвета имеют характеристики:
        // - Теплые: больше красного, меньше синего
        // - Холодные: больше синего, меньше красного
        // - Зеленая компонента должна быть между красной и синей
        
        let redValue = Double(red)
        let greenValue = Double(green)
        let blueValue = Double(blue)
        
        // Проверяем, что это не сильно насыщенный цвет
        let maxComponent = max(redValue, greenValue, blueValue)
        let minComponent = min(redValue, greenValue, blueValue)
        let saturation = (maxComponent - minComponent) / maxComponent
        
        // Если насыщенность слишком высокая, это цветной цвет
        if saturation > 0.3 {
            return nil
        }
        
        // Вычисляем соотношение синего к красному для определения температуры
        let temperatureRatio = blueValue / (redValue + 0.001) // избегаем деления на ноль
        
        // Конвертируем в позицию на шкале (0.0 = теплый, 1.0 = холодный)
        let normalizedRatio = min(max((temperatureRatio - 0.7) / (1.3 - 0.7), 0.0), 1.0)
        
        return normalizedRatio
        #else
        // Для других платформ возвращаем nil (будет использован центр)
        return nil
        #endif
    }
    
    // MARK: - Public Methods
    
    func selectTab(_ tab: ColorPickerTab) {
        selectedTab = tab
        
        // ✅ При переключении на warm/cold таб - обновляем позицию указателя
        if tab == .warmCold {
            updateWarmColdPositionForCurrentLamp()
        }
    }
    
    /// Обновляет позицию warm/cold указателя для текущей лампы
    private func updateWarmColdPositionForCurrentLamp() {
        // Получаем целевую лампу из NavigationManager
        let targetLightId: String?
        
        if let targetLight = NavigationManager.shared.targetLightForColorChange {
            targetLightId = targetLight.id
        } else if let targetRoom = NavigationManager.shared.targetRoomForColorChange {
            // Для комнаты берем первую лампу как представительную
            targetLightId = targetRoom.lightIds.first
        } else {
            return
        }
        
        guard let lightId = targetLightId else { return }
        
        // Восстанавливаем позицию для этой лампы
        restoreWarmColdPosition(for: lightId)
    }
    
    /// Получает позицию маркера в контейнере на основе относительных координат
    func getMarkerPosition(in containerSize: CGSize, imageSize: CGSize) -> CGPoint {
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        
        // Вычисляем смещение от центра на основе относительных координат
        let offsetX = (selectedColorRelativePosition.x - 0.5) * imageSize.width
        let offsetY = (selectedColorRelativePosition.y - 0.5) * imageSize.height
        
        return CGPoint(
            x: centerX + offsetX,
            y: centerY + offsetY
        )
    }
    
    /// Получает позицию маркера для warm/cold круга
    func getWarmColdMarkerPosition(in containerSize: CGSize, circleSize: CGSize) -> CGPoint {
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        
        // Вычисляем смещение от центра на основе относительных координат warm/cold
        let offsetX = (warmColdRelativePosition.x - 0.5) * circleSize.width
        let offsetY = (warmColdRelativePosition.y - 0.5) * circleSize.height
        
        return CGPoint(
            x: centerX + offsetX,
            y: centerY + offsetY
        )
    }
    
    /// Получает иконку целевой лампы
    func getTargetLightIcon() -> String {
        if let targetLight = NavigationManager.shared.targetLightForColorChange {
            return targetLight.metadata.userSubtypeIcon ?? "BulbFill"
        } else if let targetRoom = NavigationManager.shared.targetRoomForColorChange,
                  let firstLightId = targetRoom.lightIds.first {
            // Ищем первую лампу в комнате для получения иконки
            if let appViewModel = NavigationManager.shared.dataPersistenceService?.appViewModel {
                let firstLight = appViewModel.lightsViewModel.lights.first { $0.id == firstLightId }
                return firstLight?.metadata.userSubtypeIcon ?? "BulbFill"
            }
        }
        return "BulbFill"
    }
    
    func handleColorSelection(at location: CGPoint, in containerSize: CGSize, imageSize: CGSize) {
        // Вычисляем центр контейнера
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        
        // Вычисляем смещение от центра
        let offsetX = location.x - centerX
        let offsetY = location.y - centerY
        
        // Проверяем, что точка находится в пределах круга
        let radius = imageSize.width / 2
        let distance = sqrt(offsetX * offsetX + offsetY * offsetY)
        
        guard distance <= radius else { return }
        
        // Преобразуем в относительные координаты (от 0 до 1)
        selectedColorRelativePosition = CGPoint(
            x: 0.5 + offsetX / imageSize.width,
            y: 0.5 + offsetY / imageSize.height
        )
        
        #if canImport(UIKit)
        if let image = pickerImage {
            // Вычисляем позицию в изображении для получения цвета
            let imageX = (offsetX / radius + 1.0) * 0.5
            let imageY = (offsetY / radius + 1.0) * 0.5
            
            if let pixelColor = image.getPixelColorNormalized(at: CGPoint(x: imageX, y: imageY)) {
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                
                pixelColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                selectedColor = Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
                
                // ✅ ЖИВОЕ ОБНОВЛЕНИЕ: Применяем цвет к лампе сразу при перетягивании
                Task {
                    await applyLiveColorUpdate(selectedColor)
                }
                return
            }
        }
        #endif
        
        // Запасной вариант - HSV цветовое колесо
        let angle = atan2(offsetY, offsetX)
        let hue = (angle + .pi) / (2 * .pi)
        let adjustedHue = (hue + 0.75) > 1.0 ? hue - 0.25 : hue + 0.75
        let saturation = min(distance / radius, 1.0)
        
        selectedColor = Color(hue: Double(adjustedHue), saturation: Double(saturation), brightness: 1.0)
        
        // ✅ ЖИВОЕ ОБНОВЛЕНИЕ: Применяем цвет к лампе сразу при перетягивании
        Task {
            await applyLiveColorUpdate(selectedColor)
        }
    }
    
    /// Обработка выбора цвета в warm/cold круге
    func handleWarmColdColorSelection(at location: CGPoint, in containerSize: CGSize, circleSize: CGSize) {
        // Вычисляем центр контейнера
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        
        // Вычисляем смещение от центра
        let offsetX = location.x - centerX
        let offsetY = location.y - centerY
        
        // Проверяем, что точка находится в пределах круга
        let radius = circleSize.width / 2
        let distance = sqrt(offsetX * offsetX + offsetY * offsetY)
        
        guard distance <= radius else { return }
        
        // Преобразуем в относительные координаты (от 0 до 1) для warm/cold
        warmColdRelativePosition = CGPoint(
            x: 0.5 + offsetX / circleSize.width,
            y: 0.5 + offsetY / circleSize.height
        )
        
        // Вычисляем color temperature на основе горизонтальной позиции (X)
        // Левая сторона = теплый (2700K), правая сторона = холодный (6500K)
        let temperatureRatio = warmColdRelativePosition.x // 0.0 = теплый, 1.0 = холодный
        
        // Интерполируем между теплым и холодным цветом
        let warmColor = Color(red: 1.0, green: 0.7, blue: 0.4) // 2700K
        let neutralColor = Color(red: 1.0, green: 0.9, blue: 0.8) // 4000K
        let coolColor = Color(red: 0.8, green: 0.9, blue: 1.0) // 6500K
        
        // Используем температурное смешивание цветов
        if temperatureRatio <= 0.5 {
            // Между теплым и нейтральным
            let ratio = temperatureRatio * 2.0
            warmColdSelectedColor = interpolateColor(from: warmColor, to: neutralColor, ratio: ratio)
        } else {
            // Между нейтральным и холодным
            let ratio = (temperatureRatio - 0.5) * 2.0
            warmColdSelectedColor = interpolateColor(from: neutralColor, to: coolColor, ratio: ratio)
        }
        
        print("🌡️ Warm/Cold temperature ratio: \(temperatureRatio), color: \(warmColdSelectedColor)")
        
        // ✅ ЖИВОЕ ОБНОВЛЕНИЕ: Применяем цвет к лампе сразу при перетягивании
        Task {
            await applyLiveColorUpdate(warmColdSelectedColor)
        }
    }
    
    /// Применяет цвет к лампе в реальном времени (без сохранения состояния)
    @MainActor
    private func applyLiveColorUpdate(_ color: Color) async {
        do {
            // Создаем сервис с AppViewModel напрямую
            guard let appViewModel = NavigationManager.shared.dataPersistenceService?.appViewModel else {
                print("⚠️ Не удается получить AppViewModel для живого обновления")
                return
            }
            
            let lightControlService = LightControlService(appViewModel: appViewModel)
            let updatedService = LightingColorService(
                lightControlService: lightControlService,
                appViewModel: appViewModel
            )
            
            // Применяем цвет к целевому элементу БЕЗ сохранения в LightColorStateService
            if let targetLight = NavigationManager.shared.targetLightForColorChange {
                try await updatedService.setColor(for: targetLight, color: color)
                print("🎨 Живое обновление цвета лампы '\(targetLight.metadata.name)'")
                
            } else if let targetRoom = NavigationManager.shared.targetRoomForColorChange {
                try await updatedService.setColor(for: targetRoom, color: color)
                print("🎨 Живое обновление цвета комнаты '\(targetRoom.name)'")
            }
            
        } catch {
            print("❌ Ошибка при живом обновлении цвета: \(error.localizedDescription)")
        }
    }
    
    /// Интерполяция между двумя цветами
    private func interpolateColor(from: Color, to: Color, ratio: Double) -> Color {
        #if canImport(UIKit)
        let fromUIColor = UIColor(from)
        let toUIColor = UIColor(to)
        
        var fromRed: CGFloat = 0, fromGreen: CGFloat = 0, fromBlue: CGFloat = 0, fromAlpha: CGFloat = 0
        var toRed: CGFloat = 0, toGreen: CGFloat = 0, toBlue: CGFloat = 0, toAlpha: CGFloat = 0
        
        fromUIColor.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
        toUIColor.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
        
        let r = fromRed + (toRed - fromRed) * ratio
        let g = fromGreen + (toGreen - fromGreen) * ratio
        let b = fromBlue + (toBlue - fromBlue) * ratio
        let a = fromAlpha + (toAlpha - fromAlpha) * ratio
        
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
        #else
        // Fallback для других платформ
        return ratio < 0.5 ? from : to
        #endif
    }
    
    func selectWarmColdLamp(_ lampId: String) {
        for index in warmColdLamps.indices {
            warmColdLamps[index].isSelected = warmColdLamps[index].id == lampId
        }
    }
    
    func selectPalletColor(_ colorId: String) {
        for index in palletColors.indices {
            palletColors[index].isSelected = palletColors[index].id == colorId
        }
        selectedPalletColorItem = palletColors.first { $0.id == colorId }
        
        // ✅ ЖИВОЕ ОБНОВЛЕНИЕ: Применяем цвет к лампе сразу при выборе из палитры
        if let selectedItem = selectedPalletColorItem {
            Task {
                await applyLiveColorUpdate(selectedItem.color)
            }
        }
    }
    
    func saveColorSettings() {
        // Здесь будет логика сохранения настроек цвета для ламп
        print("Saving color settings for tab: \(selectedTab)")
    }
    
    // MARK: - Private Methods
    
    /// Обновляет selectedColor на основе текущей позиции указателя
    private func updateSelectedColorFromCurrentPosition() {
        #if canImport(UIKit)
        guard let image = pickerImage else {
            // Если изображение не загружено, используем HSV расчет
            updateColorUsingHSV()
            return
        }
        
        // Преобразуем относительные координаты в координаты изображения
        let imageSize = CGSize(width: 320, height: 320)
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        
        let offsetX = (selectedColorRelativePosition.x - 0.5) * imageSize.width
        let offsetY = (selectedColorRelativePosition.y - 0.5) * imageSize.height
        
        // Проверяем, что точка находится в пределах круга
        let radius = imageSize.width / 2
        let distance = sqrt(offsetX * offsetX + offsetY * offsetY)
        
        if distance <= radius {
            // Вычисляем позицию в изображении для получения цвета
            let imageX = (offsetX / radius + 1.0) * 0.5
            let imageY = (offsetY / radius + 1.0) * 0.5
            
            if let pixelColor = image.getPixelColorNormalized(at: CGPoint(x: imageX, y: imageY)) {
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                
                pixelColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                selectedColor = Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
                return
            }
        }
        #endif
        
        // Запасной вариант - HSV расчет
        updateColorUsingHSV()
    }
    
    /// Запасной метод для обновления цвета через HSV расчет
    private func updateColorUsingHSV() {
        let imageSize = CGSize(width: 320, height: 320)
        let offsetX = (selectedColorRelativePosition.x - 0.5) * imageSize.width
        let offsetY = (selectedColorRelativePosition.y - 0.5) * imageSize.height
        
        let radius = imageSize.width / 2
        let distance = sqrt(offsetX * offsetX + offsetY * offsetY)
        
        guard distance <= radius else { return }
        
        let angle = atan2(offsetY, offsetX)
        let hue = (angle + .pi) / (2 * .pi)
        let adjustedHue = (hue + 0.75) > 1.0 ? hue - 0.25 : hue + 0.75
        let saturation = min(distance / radius, 1.0)
        
        selectedColor = Color(hue: Double(adjustedHue), saturation: Double(saturation), brightness: 1.0)
    }

    /// Настройка маркеров ламп для warm/cold режима (только для комнат)
    private func setupWarmColdLamps() {
        // Если настраиваем одну лампу, не создаем дополнительные маркеры
        guard !isTargetingSingleLight else {
            warmColdLamps = []
            return
        }
        
        // Для комнаты создаем маркеры на основе ламп в комнате
        guard let targetRoom = NavigationManager.shared.targetRoomForColorChange,
              let appViewModel = NavigationManager.shared.dataPersistenceService?.appViewModel else {
            warmColdLamps = []
            return
        }
        
        let roomLights = appViewModel.lightsViewModel.lights.filter { light in
            targetRoom.lightIds.contains(light.id)
        }
        
        var lamps: [WarmColdLamp] = []
        
        // Генерируем позиции для ламп по кругу
        let positions = generateCirclePositions(count: roomLights.count, radius: 120, center: CGPoint(x: 160, y: 160))
        
        for (index, light) in roomLights.enumerated() {
            let position = positions[safe: index] ?? CGPoint(x: 160, y: 160)
            
            lamps.append(WarmColdLamp(
                id: light.id,
                position: position,
                iconName: light.metadata.userSubtypeIcon ?? "BulbFill",
                color: LightColorStateService.shared.getBaseColor(for: light),
                isSelected: index == 0 // Первая лампа выбрана по умолчанию
            ))
        }
        
        warmColdLamps = lamps
    }
    
    /// Настройка маркеров ламп для hex picker режима (только для комнат)
    private func setupRoomLightMarkers() {
        // Если настраиваем одну лампу, не создаем дополнительные маркеры
        guard !isTargetingSingleLight else {
            roomLightMarkers = []
            return
        }
        
        // Для комнаты создаем маркеры на основе ламп в комнате
        guard let targetRoom = NavigationManager.shared.targetRoomForColorChange,
              let appViewModel = NavigationManager.shared.dataPersistenceService?.appViewModel else {
            roomLightMarkers = []
            return
        }
        
        let roomLights = appViewModel.lightsViewModel.lights.filter { light in
            targetRoom.lightIds.contains(light.id)
        }
        
        var markers: [RoomLightMarker] = []
        
        // Генерируем позиции для ламп по кругу
        let positions = generateCirclePositions(count: roomLights.count, radius: 120, center: CGPoint(x: 160, y: 160))
        
        for (index, light) in roomLights.enumerated() {
            let position = positions[safe: index] ?? CGPoint(x: 160, y: 160)
            
            // Получаем сохраненный цвет или используем базовый
            let lightColor = LightColorStateService.shared.getLightColor(light.id) ??
                            LightColorStateService.shared.getBaseColor(for: light)
            
            markers.append(RoomLightMarker(
                id: light.id,
                position: position,
                iconName: light.metadata.userSubtypeIcon ?? "BulbFill",
                color: lightColor
            ))
        }
        
        roomLightMarkers = markers
    }
    
    /// Генерирует позиции по кругу для маркеров ламп
    private func generateCirclePositions(count: Int, radius: Double, center: CGPoint) -> [CGPoint] {
        guard count > 0 else { return [] }
        
        if count == 1 {
            return [center]
        }
        
        var positions: [CGPoint] = []
        let angleStep = 2 * Double.pi / Double(count)
        
        for i in 0..<count {
            let angle = Double(i) * angleStep - Double.pi / 2 // Начинаем сверху
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            positions.append(CGPoint(x: x, y: y))
        }
        
        return positions
    }
    
    private func setupPalletColors() {
        // Точные цвета из Figma (16 рядов по 9 цветов)
        let figmaColors: [String] = [
            // Ряд 1 - Красные тона
            "#991B1B", "#B91C1C", "#DC2626", "#EF4444", "#F87171", "#FCA5A5", "#FECACA", "#FEE2E2", "#FEF2F2",
            // Ряд 2 - Оранжевые тона
            "#9A3412", "#C2410C", "#EA580C", "#F97316", "#FB923C", "#FDBA74", "#FED7AA", "#FFEDD5", "#FFF7ED",
            // Ряд 3 - Янтарные тона
            "#92400E", "#B45309", "#D97706", "#F59E0B", "#FBBF24", "#FCD34D", "#FDE68A", "#FEF3C7", "#FFFBEB",
            // Ряд 4 - Желтые тона
            "#854D0E", "#A16207", "#CA8A04", "#EAB308", "#FACC15", "#FDE047", "#FEF08A", "#FEF9C3", "#FEFCE8",
            // Ряд 5 - Лаймовые тона
            "#3F6212", "#4D7C0F", "#65A30D", "#84CC16", "#A3E635", "#BEF264", "#D9F99D", "#ECFCCB", "#F7FEE7",
            // Ряд 6 - Зеленые тона
            "#166534", "#15803D", "#16A34A", "#22C55E", "#4ADE80", "#86EFAC", "#BBF7D0", "#DCFCE7", "#F0FDF4",
            // Ряд 7 - Изумрудные тона
            "#065F46", "#047857", "#059669", "#10B981", "#34D399", "#6EE7B7", "#A7F3D0", "#D1FAE5", "#ECFDF5",
            // Ряд 8 - Бирюзовые тона
            "#115E59", "#0F766E", "#0D9488", "#14B8A6", "#2DD4BF", "#5EEAD4", "#99F6E4", "#CCFBF1", "#F0FDFA",
            // Ряд 9 - Голубые тона
            "#155E75", "#0E7490", "#0891B2", "#06B6D4", "#22D3EE", "#67E8F9", "#A5F3FC", "#CFFAFE", "#ECFEFF",
            // Ряд 10 - Синие тона
            "#075985", "#0369A1", "#0284C7", "#0EA5E9", "#38BDF8", "#7DD3FC", "#BAE6FD", "#E0F2FE", "#F0F9FF",
            // Ряд 11 - Индиго тона
            "#1E40AF", "#1D4ED8", "#2563EB", "#3B82F6", "#60A5FA", "#93C5FD", "#BFDBFE", "#DBEAFE", "#EFF6FF",
            // Ряд 12 - Фиолетовые тона
            "#3730A3", "#4338CA", "#4F46E5", "#6366F1", "#818CF8", "#A5B4FC", "#C7D2FE", "#E0E7FF", "#EEF2FF",
            // Ряд 13 - Пурпурные тона
            "#5B21B6", "#6D28D9", "#7C3AED", "#8B5CF6", "#A78BFA", "#C4B5FD", "#DDD6FE", "#EDE9FE", "#F5F3FF",
            // Ряд 14 - Фуксия тона
            "#6B21A8", "#7E22CE", "#9333EA", "#A855F7", "#C084FC", "#D8B4FE", "#E9D5FF", "#F3E8FF", "#FAF5FF",
            // Ряд 15 - Розовые тона
            "#86198F", "#A21CAF", "#C026D3", "#D946EF", "#E879F9", "#F0ABFC", "#F5D0FE", "#FAE8FF", "#FDF4FF",
            // Ряд 16 - Алые тона
            "#9D174D", "#BE185D", "#DB2777", "#EC4899", "#F472B6", "#F9A8D4", "#FBCFE8", "#FCE7F3", "#FDF2F8",
            // Ряд 17 - Последний ряд
            "#9F1239", "#BE123C", "#E11D48", "#F43F5E", "#FB7185", "#FDA4AF", "#FECDD3", "#FFE4E6", "#FFF1F2",
        ]
        
        var colors: [PalletColorItem] = []
        
        // Создаем элементы палитры
        for (index, hexColor) in figmaColors.enumerated() {
            let row = index / 9
            let col = index % 9
            
            colors.append(PalletColorItem(
                id: "figma_color_\(row)_\(col)",
                color: Color(hex: hexColor),
                isSelected: row == 1 && col == 3 // Выбираем оранжевый цвет по умолчанию
            ))
        }
        
        palletColors = colors
        selectedPalletColorItem = colors.first { $0.isSelected }
    }
}