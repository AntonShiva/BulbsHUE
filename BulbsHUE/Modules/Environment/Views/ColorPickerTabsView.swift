//
//  ColorPickerTabsView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import SwiftUI
import Combine

// MARK: - ColorPickerTabsView

/// Отдельное представление для трех вкладок COLOR PICKER
/// Замещает секции при выборе COLOR PICKER таба
struct ColorPickerTabsView: View {
    @StateObject private var viewModel = ColorPickerTabsViewModel()
    
    var body: some View {
        VStack(spacing: 9) {
            // Табы (HEX PICKER, WARM/COLD, PALLET)
            colorPickerTabs
            
            // Основной контент в зависимости от выбранной вкладки
            selectedTabContent
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
            ZStack {
                // Используем существующее изображение ColorCircl.png
                Image("ColorCircl")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 320, height: 320)
                
                // Маркер текущего выбранного цвета с "+3"
                if let position = viewModel.selectedColorPosition {
                    VStack(spacing: 4) {
                        // Круглый маркер с иконкой лампочки
                        ZStack {
                            // Фон маркера
                            Circle()
                                .fill(viewModel.selectedColor)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                            
                            // Иконка лампочки
                            Image("BulbFill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(.black)
                        }
                        
                        // Счетчик "+3"
                        Text("+3")
                            .font(Font.custom("DMSans-SemiBold", size: 16))
                            .kerning(2.04)
                            .foregroundColor(.black)
                            .textCase(.uppercase)
                    }
                    .position(position)
                }
            }
            .onTapGesture { location in
                viewModel.handleColorSelection(at: location, in: CGSize(width: 320, height: 320))
            }
            
            // Контроллеры яркости
            brightnessControls
            
            // Кнопка SAVE
            saveButton
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
            
            // Контроллеры яркости
            brightnessControls
            
            // Кнопка SAVE
            saveButton
        }
    }
    
    // MARK: - Pallet Content
    
    /// Палитра цветов в виде сетки
    private var palletContent: some View {
        VStack(spacing: 32) {
            // Сетка цветов
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
            .frame(width: 356)
            .opacity(0.8)
            
            // Выбранный цветовой маркер
            if let selectedColorItem = viewModel.selectedPalletColorItem {
                VStack(spacing: 8) {
                    // Большой круг с выбранным цветом и лампочкой
                    ZStack {
                        Circle()
                            .fill(selectedColorItem.color)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(.black.opacity(0.5), lineWidth: 2)
                            )
                        
                        Image("BulbFill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.black)
                    }
                }
            }
            
            // Контроллеры яркости для каждой лампы
            multiLampBrightnessControls
            
            // Кнопка SAVE
            saveButton
        }
    }
    
    // MARK: - Common UI Components
    
    /// Контроллеры яркости (общие для первых двух вкладок)
    private var brightnessControls: some View {
        VStack(spacing: 12) {
            Text("BRIGHTNESS, %")
                .font(Font.custom("DMSans-ExtraLight", size: 12))
                .kerning(2.04)
                .foregroundColor(.white)
                .textCase(.uppercase)
            
            // Слайдер яркости
            HStack {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 312, height: 56)
                    .cornerRadius(12)
                    .overlay(
                        HStack {
                            Rectangle()
                                .fill(.white)
                                .frame(width: 140, height: 56)
                                .cornerRadius(12)
                            Spacer()
                        }
                    )
                    .overlay(
                        HStack {
                            Spacer()
                            Text("24%")
                                .font(Font.custom("DMSans-ExtraLight", size: 12))
                                .kerning(2.04)
                                .foregroundColor(.white)
                                .textCase(.uppercase)
                                .padding(.trailing, 24)
                        }
                    )
            }
        }
    }
    
    /// Контроллеры яркости для нескольких ламп (для палитры)
    private var multiLampBrightnessControls: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { index in
                VStack(spacing: 8) {
                    Text("BRIGHTNESS, %")
                        .font(Font.custom("DMSans-ExtraLight", size: 12))
                        .kerning(2.04)
                        .foregroundColor(.white)
                        .textCase(.uppercase)
                    
                    // Слайдер яркости с разными цветами
                    HStack {
                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 312, height: 56)
                            .cornerRadius(12)
                            .overlay(
                                HStack {
                                    Rectangle()
                                        .fill(viewModel.getLampBrightnessColor(for: index))
                                        .frame(width: 140, height: 56)
                                        .cornerRadius(12)
                                    Spacer()
                                }
                            )
                            .overlay(
                                HStack {
                                    Spacer()
                                    Text("24%")
                                        .font(Font.custom("DMSans-ExtraLight", size: 12))
                                        .kerning(2.04)
                                        .foregroundColor(.white)
                                        .textCase(.uppercase)
                                        .padding(.trailing, 24)
                                }
                            )
                    }
                }
            }
        }
    }
    
    /// Кнопка сохранения
    private var saveButton: some View {
        Button {
            viewModel.saveColorSettings()
        } label: {
            ZStack {
                // Фон кнопки
                Rectangle()
                    .fill(Color(red: 0.4, green: 0.75, blue: 0.55).opacity(0.05))
                    .frame(width: 254, height: 122)
                    .cornerRadius(18)
                    .overlay(
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 200, height: 64)
                            .cornerRadius(14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.4, green: 0.75, blue: 0.5).opacity(0.3),
                                        Color(red: 0.3, green: 0.65, blue: 0.7).opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(14)
                    )
                
                Text("SAVE")
                    .font(Font.custom("DMSans-Bold", size: 16))
                    .kerning(3.2)
                    .foregroundColor(.white)
                    .textCase(.uppercase)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ViewModel

/// ViewModel для управления состоянием цветовых вкладок
@MainActor
class ColorPickerTabsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedTab: ColorPickerTab = .hexPicker
    @Published var selectedColor: Color = .orange
    @Published var selectedColorPosition: CGPoint?
    @Published var warmColdLamps: [WarmColdLamp] = []
    @Published var palletColors: [PalletColorItem] = []
    @Published var selectedPalletColorItem: PalletColorItem?
    
    // MARK: - Initialization
    
    init() {
        setupWarmColdLamps()
        setupPalletColors()
        selectedColorPosition = CGPoint(x: 221, y: 287) // Начальная позиция как в Figma
    }
    
    // MARK: - Public Methods
    
    func selectTab(_ tab: ColorPickerTab) {
        selectedTab = tab
    }
    
    func handleColorSelection(at location: CGPoint, in size: CGSize) {
        // Вычисляем цвет на основе позиции в круге
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let angle = atan2(location.y - center.y, location.x - center.x)
        let distance = sqrt(pow(location.x - center.x, 2) + pow(location.y - center.y, 2))
        
        // Ограничиваем выбор в пределах круга
        guard distance <= size.width / 2 else { return }
        
        // Преобразуем угол в цвет
        let hue = (angle + .pi) / (2 * .pi)
        let saturation = min(distance / (size.width / 2), 1.0)
        
        selectedColor = Color(hue: hue, saturation: saturation, brightness: 1.0)
        selectedColorPosition = location
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
    
    func getLampBrightnessColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.976, green: 0.451, blue: 0.188), // Оранжевый
            Color(red: 0.984, green: 0.792, blue: 0.475), // Желтоватый  
            Color(red: 0.984, green: 0.941, blue: 0.541)  // Желтый
        ]
        return colors[safe: index] ?? .orange
    }
    
    func saveColorSettings() {
        // Здесь будет логика сохранения настроек цвета для ламп
        print("Saving color settings for tab: \(selectedTab)")
    }
    
    // MARK: - Private Methods
    
    private func setupWarmColdLamps() {
        warmColdLamps = [
            WarmColdLamp(
                id: "lamp1",
                position: CGPoint(x: 177, y: 301),
                iconName: "floor-lamp-2",
                isSelected: false
            ),
            WarmColdLamp(
                id: "lamp2",
                position: CGPoint(x: 187, y: 278),
                iconName: "BulbFill",
                isSelected: true
            ),
            WarmColdLamp(
                id: "lamp3",
                position: CGPoint(x: 208, y: 406),
                iconName: "BulbFill",
                isSelected: false
            )
        ]
    }
    
    private func setupPalletColors() {
        // Создаем упрощенную палитру цветов (9x10 сетка)
        let baseColors: [Color] = [
            // Красные оттенки
            .red, Color(red: 0.8, green: 0.2, blue: 0.2), Color(red: 0.9, green: 0.4, blue: 0.4),
            // Оранжевые оттенки  
            .orange, Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.8, blue: 0.4),
            // Желтые оттенки
            .yellow, Color(red: 0.9, green: 0.9, blue: 0.2), Color(red: 1.0, green: 1.0, blue: 0.6),
            // Зеленые оттенки
            .green, Color(red: 0.2, green: 0.8, blue: 0.2), Color(red: 0.4, green: 0.9, blue: 0.4),
            // Синие оттенки
            .blue, Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.4, green: 0.6, blue: 0.9),
            // Фиолетовые оттенки
            .purple, Color(red: 0.6, green: 0.2, blue: 0.8), Color(red: 0.8, green: 0.4, blue: 0.9),
            // Розовые оттенки  
            .pink, Color(red: 1.0, green: 0.4, blue: 0.7), Color(red: 1.0, green: 0.7, blue: 0.9),
            // Коричневые и серые
            .brown, .gray, .black
        ]
        
        // Создаем расширенную палитру с вариациями яркости
        var colors: [PalletColorItem] = []
        var colorIndex = 0
        
        // Создаем около 80 цветов для заполнения сетки
        for row in 0..<9 {
            for col in 0..<9 {
                let baseColor = baseColors[colorIndex % baseColors.count]
                let brightness = 1.0 - (Double(col) * 0.1) // Уменьшаем яркость слева направо
                _ = 0.5 + (Double(row) * 0.05) // Увеличиваем насыщенность сверху вниз (не используется)
                
                let adjustedColor = baseColor.opacity(brightness)
                
                colors.append(PalletColorItem(
                    id: "color_\(row)_\(col)",
                    color: adjustedColor,
                    isSelected: row == 1 && col == 3 // Выделяем оранжевый цвет по умолчанию
                ))
                
                if col % 3 == 2 { colorIndex += 1 } // Переходим к следующему базовому цвету каждые 3 колонки
            }
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

// MARK: - Preview

#Preview("Color Picker Tabs") {
    ZStack {
        Color.black.ignoresSafeArea()
        ColorPickerTabsView()
    }
}
