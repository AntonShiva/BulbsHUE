//
//  ColorPickerTabsView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ColorPickerTabsView

/// Отдельное представление для трех вкладок COLOR PICKER
/// Замещает секции при выборе COLOR PICKER таба
struct ColorPickerTabsView: View {
    @StateObject private var viewModel = ColorPickerTabsViewModel()
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var appViewModel: AppViewModel
    

    
    var body: some View {
       ZStack {
            // Табы (HEX PICKER, WARM/COLD, PALLET)
            colorPickerTabs
               .adaptiveOffset(y: -250)
            
            // Основной контент в зависимости от выбранной вкладки
            selectedTabContent
               .adaptiveOffset(y: -60)
           
           SaveButtonRec {
               // Применяем выбранный цвет к целевой лампе или комнате
               Task {
                   await applySelectedColor()
               }
           }
           .adaptiveOffset(y: 225)
        }
    }
    
    // MARK: - Color Picker Tabs
    
    /// Табы для выбора типа цветовой панели
    private var colorPickerTabs: some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                // HEX PICKER tab
                Button {
                    viewModel.selectTab(.hexPicker)
                } label: {
                    Text("HEX PICKER")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(viewModel.selectedTab == .hexPicker ? .white : .white.opacity(0.6))
                        .textCase(.uppercase)
                        .frame(width: 120)
                }
                .buttonStyle(PlainButtonStyle())
                
                // WARM / COLD tab
                Button {
                    viewModel.selectTab(.warmCold)
                } label: {
                    Text("WARM / COLD")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(viewModel.selectedTab == .warmCold ? .white : .white.opacity(0.6))
                        .textCase(.uppercase)
                        .frame(width: 120)
                }
                .buttonStyle(PlainButtonStyle())
                
                // PALLET tab
                Button {
                    viewModel.selectTab(.pallet)
                } label: {
                    Text("PALLET")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(viewModel.selectedTab == .pallet ? .white : .white.opacity(0.6))
                        .textCase(.uppercase)
                        .frame(width: 120)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Индикатор активной вкладки
            tabIndicator
        }
    }
    
    /// Индикатор под выбранной вкладкой
    private var tabIndicator: some View {
        HStack(spacing: 0) {
            if viewModel.selectedTab == .hexPicker {
                Rectangle()
                    .fill(.white)
                    .frame(width: 120, height: 1)
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 240, height: 1)
            } else if viewModel.selectedTab == .warmCold {
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 120, height: 1)
                Rectangle()
                    .fill(.white)
                    .frame(width: 120, height: 1)
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 120, height: 1)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 240, height: 1)
                Rectangle()
                    .fill(.white)
                    .frame(width: 120, height: 1)
            }
        }
    }
    
    // MARK: - Selected Tab Content
    
    /// Контент для выбранной вкладки
    @ViewBuilder
    private var selectedTabContent: some View {
        switch viewModel.selectedTab {
        case .hexPicker:
            hexPickerContent
        case .warmCold:
            warmColdContent
        case .pallet:
            palletContent
        }
    }
    
    // MARK: - HEX Picker Content
    
    /// Круглая цветовая панель для HEX выбора
    private var hexPickerContent: some View {
        VStack(spacing: 32) {
            // Основная круглая цветовая панель (радуга)
            GeometryReader { geometry in
                ZStack {
                    // Используем существующее изображение ColorCircl.png
                    Image("ColorCircl")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 320, height: 320)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    viewModel.handleColorSelection(
                                        at: value.location, 
                                        in: geometry.size,
                                        imageSize: CGSize(width: 320, height: 320)
                                    )
                                }
                        )
                    
                    // ЕДИНСТВЕННЫЙ маркер - цель/лампа которую можно перетаскивать
                    VStack(spacing: 4) {
                        ZStack {
                            PointerBulb(color: viewModel.selectedColor)
                            
                            // Иконка лампочки в центре
                            Image("BulbFill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.black.opacity(0.8))
                                .adaptiveOffset(y: -3)
                        }
                    }
                    .position(viewModel.getMarkerPosition(in: geometry.size, imageSize: CGSize(width: 320, height: 320)))
                }
            }
            .frame(height: 320)
            
          

        }
    }
    
    // MARK: - Warm/Cold Content
    
    /// Градиентный круг с лампочками для теплых/холодных тонов
    private var warmColdContent: some View {
        VStack(spacing: 32) {
            // Градиентный круг (от оранжевого к холодному)
            ZStack {
                // Градиентный фон от теплого к холодному
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.5, blue: 0.0), // Теплый оранжевый
                                Color(red: 1.0, green: 0.85, blue: 0.7), // Нейтральный
                                Color(red: 0.7, green: 0.85, blue: 1.0)  // Холодный синеватый
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 320, height: 320)
                
                // Маркеры ламп на градиенте
                ForEach(viewModel.warmColdLamps, id: \.id) { lamp in
                    VStack(spacing: 4) {
                        // Круглый маркер с иконкой
                        ZStack {
                            Circle()
                                .fill(lamp.isSelected ? .white : Color.white.opacity(0.8))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(.black.opacity(0.2), lineWidth: 2)
                                )
                            
                            // Иконка лампочки или торшера
                            Image(lamp.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(.black)
                        }
                        .onTapGesture {
                            viewModel.selectWarmColdLamp(lamp.id)
                        }
                    }
                    .position(lamp.position)
                }
            }
            
        }
    }
    
    // MARK: - Pallet Content
    
    /// Палитра цветов в виде сетки (точно как в Figma)
    private var palletContent: some View {
        VStack(spacing: 32) {
            // Сетка цветов точно как в Figma 9x16 (356 width)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 4), count: 9), spacing: 4) {
                    ForEach(viewModel.palletColors, id: \.id) { colorItem in
                        Rectangle()
                            .fill(colorItem.color)
                            .frame(width: 36, height: 36)
                            .cornerRadius(6)
                            .overlay(
                                Rectangle()
                                    .stroke(colorItem.isSelected ? .white : .clear, lineWidth: 2)
                                    .cornerRadius(6)
                            )
                            .onTapGesture {
                                viewModel.selectPalletColor(colorItem.id)
                            }
                    }
                }
                .adaptiveFrame(width: 356)
               
            }
           Spacer()
                .adaptiveFrame(height: 380)
//            // Выбранный цветовой маркер
//            if let selectedColorItem = viewModel.selectedPalletColorItem {
//                VStack(spacing: 8) {
//                    // Большой круг с выбранным цветом и лампочкой
//                    ZStack {
//                        Circle()
//                            .fill(selectedColorItem.color)
//                            .frame(width: 56, height: 56)
//                            .overlay(
//                                Circle()
//                                    .stroke(.black.opacity(0.5), lineWidth: 2)
//                            )
//                        
//                        Image("BulbFill")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 24, height: 24)
//                            .foregroundColor(.black)
//                    }
//                }
//            }
           
        }
        .adaptiveOffset(y: 250)
    }
    
    // MARK: - Helper Methods
    
    /// Применить выбранный цвет к целевой лампе или комнате
    @MainActor
    private func applySelectedColor() async {
        do {
            // Определяем выбранный цвет в зависимости от активной вкладки
            let colorToApply: Color
            
            switch viewModel.selectedTab {
            case .hexPicker:
                colorToApply = viewModel.selectedColor
            case .warmCold:
                // Для теплого/холодного используем цвет из выбранной лампы
                if let selectedLamp = viewModel.warmColdLamps.first(where: { $0.isSelected }) {
                    colorToApply = selectedLamp.color
                } else {
                    colorToApply = viewModel.selectedColor
                }
            case .pallet:
                // Для палитры используем цвет из выбранного элемента
                if let selectedPalletItem = viewModel.selectedPalletColorItem {
                    colorToApply = selectedPalletItem.color
                } else {
                    colorToApply = viewModel.selectedColor
                }
            }
            
            // Создаем сервис с AppViewModel напрямую
            let lightControlService = LightControlService(appViewModel: appViewModel)
            let updatedService = LightingColorService(
                lightControlService: lightControlService,
                appViewModel: appViewModel
            )
            
            // Применяем цвет к целевому элементу
            if let targetLight = nav.targetLightForColorChange {
                print("🎨 Применяем цвет к лампе '\(targetLight.metadata.name)'")
                try await updatedService.setColor(for: targetLight, color: colorToApply)
                
                // ✅ ИСПРАВЛЕНИЕ: Сохраняем состояние цвета в LightColorStateService
                let colorPosition = viewModel.selectedTab == .hexPicker ? viewModel.selectedColorRelativePosition : nil
                LightColorStateService.shared.setLightColor(
                    targetLight.id, 
                    color: colorToApply, 
                    position: colorPosition
                )
                
                // Показываем успешное уведомление
                print("✅ Цвет лампы '\(targetLight.metadata.name)' успешно изменен")
                
            } else if let targetRoom = nav.targetRoomForColorChange {
                print("🎨 Применяем цвет к комнате '\(targetRoom.name)'")
                try await updatedService.setColor(for: targetRoom, color: colorToApply)
                
                // ✅ ИСПРАВЛЕНИЕ: Сохраняем состояние цвета для всех ламп в комнате
               
                    let roomLights = appViewModel.lightsViewModel.lights.filter { light in
                        targetRoom.lightIds.contains(light.id)
                    }
                    
                    let colorPosition = viewModel.selectedTab == .hexPicker ? viewModel.selectedColorRelativePosition : nil
                    for light in roomLights {
                        LightColorStateService.shared.setLightColor(
                            light.id, 
                            color: colorToApply, 
                            position: colorPosition
                        )
                    }
                
                
                // Показываем успешное уведомление
                print("✅ Цвет всех ламп в комнате '\(targetRoom.name)' успешно изменен")
            } else {
                print("⚠️ Не выбрана целевая лампа или комната для изменения цвета")
                return
            }
            
            // Возвращаемся к предыдущему экрану после успешного применения
            await MainActor.run {
                nav.hideEnvironmentBulbs()
            }
            
        } catch {
            print("❌ Ошибка при применении цвета: \(error.localizedDescription)")
            // Здесь можно показать alert с ошибкой пользователю
        }
    }
}

// MARK: - ViewModel

/// ViewModel для управления состоянием цветовых вкладок
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
    
    #if canImport(UIKit)
    @Published var pickerImage: UIImage? = nil
    #endif
    
    // MARK: - Initialization
    
    init() {
        setupWarmColdLamps()
        setupPalletColors()
        
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
        
        // Восстанавливаем сохраненный цвет и позицию
        if let savedColor = LightColorStateService.shared.getLightColor(lightId) {
            selectedColor = savedColor
            print("🔄 Восстановлен цвет для лампы \(lightId)")
        }
        
        if let savedPosition = LightColorStateService.shared.getColorPickerPosition(lightId) {
            selectedColorRelativePosition = savedPosition
            print("🔄 Восстановлена позиция color picker для лампы \(lightId)")
        }
    }
    
    // MARK: - Public Methods
    
    func selectTab(_ tab: ColorPickerTab) {
        selectedTab = tab
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

    private func setupWarmColdLamps() {
        warmColdLamps = [
            WarmColdLamp(
                id: "lamp1",
                position: CGPoint(x: 177, y: 301),
                iconName: "floor-lamp-2",
                color: Color(red: 1.0, green: 0.9, blue: 0.7), // Теплый белый
                isSelected: false
            ),
            WarmColdLamp(
                id: "lamp2",
                position: CGPoint(x: 187, y: 278),
                iconName: "BulbFill",
                color: Color(red: 1.0, green: 0.95, blue: 0.8), // Нейтральный белый
                isSelected: true
            ),
            WarmColdLamp(
                id: "lamp3",
                position: CGPoint(x: 208, y: 406),
                iconName: "BulbFill",
                color: Color(red: 0.9, green: 0.95, blue: 1.0), // Холодный белый
                isSelected: false
            )
        ]
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

// MARK: - Data Models

/// Тип вкладки цветовыбора
enum ColorPickerTab: CaseIterable {
    case hexPicker
    case warmCold  
    case pallet
}

/// Модель лампы для теплых/холодных тонов
struct WarmColdLamp: Identifiable {
    let id: String
    let position: CGPoint
    let iconName: String
    let color: Color
    var isSelected: Bool
}

/// Модель цветового элемента палитры
struct PalletColorItem: Identifiable {
    let id: String
    let color: Color
    var isSelected: Bool
}

// MARK: - Extensions

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Color {
    /// Создание Color из HEX строки
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview("Color Picker Tabs") {
    ZStack {
        Color.black.ignoresSafeArea()
        ColorPickerTabsView()
    }
}

// MARK: - UIImage Extension

#if canImport(UIKit)
/// Расширение UIImage для получения цвета пикселя
extension UIImage {
    /// Получает цвет пикселя изображения в указанной позиции
    /// - Parameter pos: Позиция пикселя в координатах изображения (от 0 до размера изображения)
    /// - Returns: UIColor цвет пикселя или nil, если позиция находится вне границ изображения
    func getPixelColor(at pos: CGPoint) -> UIColor? {
        // Проверяем, что точка находится в пределах изображения
        guard let cgImage = self.cgImage,
              pos.x >= 0, pos.y >= 0,
              pos.x < size.width * scale, pos.y < size.height * scale else {
            return nil
        }
        
        // Преобразуем координаты в целочисленный индекс пикселя
        let x = Int(pos.x * scale)
        let y = Int(pos.y * scale)
        
        // Создаем контекст для доступа к данным пикселя
        let dataProvider = cgImage.dataProvider
        guard let data = dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }
        
        // Получаем информацию о формате пикселей
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        // Вычисляем индекс начала данных пикселя
        let pixelIndex = y * bytesPerRow + x * bytesPerPixel
        
        // Получаем компоненты цвета из данных пикселя
        let r = CGFloat(bytes[pixelIndex]) / 255.0
        let g = CGFloat(bytes[pixelIndex + 1]) / 255.0
        let b = CGFloat(bytes[pixelIndex + 2]) / 255.0
        let a = bytesPerPixel > 3 ? CGFloat(bytes[pixelIndex + 3]) / 255.0 : 1.0
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    /// Получает цвет пикселя изображения в указанной нормализованной позиции
    /// - Parameter normalizedPos: Нормализованная позиция (от 0 до 1)
    /// - Returns: UIColor цвет пикселя или nil, если позиция находится вне границ изображения
    func getPixelColorNormalized(at normalizedPos: CGPoint) -> UIColor? {
        let x = normalizedPos.x * size.width
        let y = normalizedPos.y * size.height
        return getPixelColor(at: CGPoint(x: x, y: y))
    }
}
#endif


#Preview("Environment Bulbs View") {
    EnvironmentBulbsView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
}
