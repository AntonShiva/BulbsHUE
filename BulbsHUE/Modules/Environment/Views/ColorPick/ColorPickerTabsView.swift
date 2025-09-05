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
    @State private var viewModel = ColorPickerTabsViewModel()
    @Environment(NavigationManager.self) private var nav
    @Environment(AppViewModel.self) private var appViewModel
    

    
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
                    
                    // Отображаем маркеры в зависимости от режима
                    if viewModel.isTargetingSingleLight {
                        // Для одной лампы - один маркер
                        VStack(spacing: 4) {
                            ZStack {
                                PointerBulb(color: viewModel.selectedColor)
                                
                                // Иконка целевой лампы
                                Image(viewModel.getTargetLightIcon())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.black.opacity(0.8))
                                    .adaptiveOffset(y: -3)
                            }
                        }
                        .position(viewModel.getMarkerPosition(in: geometry.size, imageSize: CGSize(width: 320, height: 320)))
                    } else {
                        // Для комнаты - маркеры всех ламп
                        ForEach(viewModel.roomLightMarkers, id: \.id) { marker in
                            VStack(spacing: 4) {
                                ZStack {
                                    PointerBulb(color: marker.color)
                                    
                                    // Иконка лампы из комнаты
                                    Image(marker.iconName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.black.opacity(0.8))
                                        .adaptiveOffset(y: -2)
                                }
                            }
                            .position(marker.position)
                        }
                    }
                }
            }
            .frame(height: 320)
        }
    }
    
    // MARK: - Warm/Cold Content
    
    /// Градиентный круг с лампочками для теплых/холодных тонов
    private var warmColdContent: some View {
        VStack(spacing: 32) {
            // Градиентный круг (от теплого к холодному)
            GeometryReader { geometry in
                ZStack {
                    // Градиентный фон от теплого к холодному (2700K-6500K)
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.7, blue: 0.4), // Теплый 2700K (желтый/оранжевый)
                                    Color(red: 1.0, green: 0.9, blue: 0.8), // Нейтральный 4000K
                                    Color(red: 0.8, green: 0.9, blue: 1.0)  // Холодный 6500K (синеватый)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 320, height: 320)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    viewModel.handleWarmColdColorSelection(
                                        at: value.location,
                                        in: geometry.size,
                                        circleSize: CGSize(width: 320, height: 320)
                                    )
                                }
                        )
                    
                    // Отображаем маркеры в зависимости от режима
                    if viewModel.isTargetingSingleLight {
                        // Для одной лампы - один маркер как в hex picker
                        VStack(spacing: 4) {
                            ZStack {
                                PointerBulb(color: viewModel.warmColdSelectedColor)
                                
                                // Иконка целевой лампы
                                Image(viewModel.getTargetLightIcon())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.black.opacity(0.8))
                                    .adaptiveOffset(y: -3)
                            }
                        }
                        .position(viewModel.getWarmColdMarkerPosition(in: geometry.size, circleSize: CGSize(width: 320, height: 320)))
                    } else {
                        // Для комнаты - маркеры всех ламп
                        ForEach(viewModel.warmColdLamps, id: \.id) { lamp in
                            VStack(spacing: 4) {
                                // Круглый маркер с иконкой лампы
                                ZStack {
                                    Circle()
                                        .fill(lamp.isSelected ? .white : Color.white.opacity(0.8))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(.black.opacity(0.2), lineWidth: 2)
                                        )
                                    
                                    // Иконка лампы из комнаты
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
            .frame(height: 320)
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
                // Для теплого/холодного используем выбранный warm/cold цвет
                colorToApply = viewModel.warmColdSelectedColor
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
                let colorPosition = viewModel.selectedTab == .hexPicker ? viewModel.selectedColorRelativePosition : 
                                  viewModel.selectedTab == .warmCold ? viewModel.warmColdRelativePosition : nil
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
                    
                    let colorPosition = viewModel.selectedTab == .hexPicker ? viewModel.selectedColorRelativePosition : 
                                      viewModel.selectedTab == .warmCold ? viewModel.warmColdRelativePosition : nil
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

/// Модель маркера лампы для hex picker (комнатный режим)
struct RoomLightMarker: Identifiable {
    let id: String
    let position: CGPoint
    let iconName: String
    let color: Color
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
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
}
