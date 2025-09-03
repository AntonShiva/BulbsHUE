//
//  EnvironmentBulbsView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import SwiftUI
import Combine

// Импорт новых моделей из архитектуры
// Будет добавлен автоматически при компиляции проекта

// MARK: - EnvironmentBulbsView

/// Экран выбора окружающих сцен освещения
/// Отображает коллекцию природных сцен для настройки освещения
struct EnvironmentBulbsView: View {
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var appViewModel: AppViewModel
    
    /// ViewModel для управления состоянием экрана
    @StateObject private var viewModel = EnvironmentBulbsViewModel()
    
    /// Состояние показа щита тоглов ламп
    @State private var showBulbTogglesPanel = false
    
    
    
    var body: some View {
        ZStack {
            // Основной градиентный фон
            BGLight()
            navigationHeader
                .adaptiveOffset(y: -329)
            
            // Blur панель с табами фильтров
            filterTabs
                .adaptiveOffset(y: -240)
            
            // Контент в зависимости от выбранного фильтра
            if viewModel.selectedFilterTab == .colorPicker {
                // Показываем цветовые вкладки вместо секций
                ColorPickerTabsView()
                    .adaptiveOffset(y: 70)
            } else {
                // Секционные табы для других фильтров
                sectionTabs
                    .adaptiveOffset(y: -179)
                
                // Сетка изображений сцен
                sceneGrid
                    .adaptiveOffset(y: 262)
            }
            
            if showBulbTogglesPanel {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showBulbTogglesPanel = false
                    }
                } label: {
                    ZStack() {
                        Image("BGPresetBulb")
                            .resizable()
                            .scaledToFit()
                            .adaptiveFrame(width: 375, height: 240)
                        
                        Text("BULB")
                            .font(Font.custom("DMSans-Bold", size: 16.5))
                            .kerning(3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                            .textCase(.uppercase)
                            .adaptiveOffset(x: 70,y: 22)
                            .blur(radius: 0.5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .adaptiveOffset(x: 50,y: 280)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showBulbTogglesPanel = true
                    }
                } label: {
                    ZStack() {
                        Image("BGPresetBulb")
                            .resizable()
                            .scaledToFit()
                            .adaptiveFrame(width: 375, height: 240)
                        
                        Text("BULB")
                            .font(Font.custom("DMSans-Bold", size: 16.5))
                            .kerning(3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                            .textCase(.uppercase)
                            .adaptiveOffset(x: 70,y: 22)
                            .blur(radius: 0.5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .adaptiveOffset(x: 50,y: 280)
            }
            
            if showBulbTogglesPanel {
                bulbCenterView
                    .adaptiveOffset(y: 293)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .ignoresSafeArea(.all)
    }
    
    // MARK: - Helper Methods
    
    /// Получить имя целевого элемента (лампы или комнаты) для заголовка
    private func getTargetElementName() -> String {
        if let targetLight = nav.targetLightForColorChange {
            return targetLight.metadata.name.uppercased()
        } else if let targetRoom = nav.targetRoomForColorChange {
            return targetRoom.name.uppercased()
        } else {
            return "BULB"
        }
    }
    
    // MARK: - Navigation Header
    
    /// Верхняя навигационная панель с кнопками и заголовком
    private var navigationHeader: some View {
        Header(title: getTargetElementName()) {
            ChevronButton {
                nav.hideEnvironmentBulbs()
            }
            .rotationEffect(.degrees(180))
        } leftView2: {
            // Центральная кнопка - FAV
            Button {
                viewModel.toggleFavoriteFilter()
            } label: {
                ZStack {
                    BGCircle()
                        .adaptiveFrame(width: 48, height: 48)
                    
                    // Heart icon
                    Image(systemName: !viewModel.isFavoriteFilterActive ? "heart.fill" : "heart")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundColor(.primColor)
                    
                    Text("FAV")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(.primColor)
                        .textCase(.uppercase)
                        .adaptiveOffset(y: 40)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        } rightView1: {
            // Правая кнопка - Brightness/On
            Button {
                viewModel.toggleMainLight()
            } label: {
                ZStack {
                    BGCircle()
                        .adaptiveFrame(width: 48, height: 48)
                    
                    Image("BulbFill")
                        .resizable()
                        .scaledToFit()
                        .adaptiveFrame(width: 30, height: 30)
                    
                    Text("ON")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(.primColor)
                        .textCase(.uppercase)
                        .adaptiveOffset(y: 40)
                    
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        } rightView2: {
            
            // Дальняя правая кнопка - Sun/Settings
            Button {
                viewModel.toggleSunMode()
            } label: {
                ZStack {
                    BGCircle()
                        .adaptiveFrame(width: 48, height: 48)
                    
                    Image("sun")
                        .resizable()
                        .scaledToFit()
                        .adaptiveFrame(width: 30, height: 30)
                    
                    Text("50%")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(.primColor)
                        .textCase(.uppercase)
                        .adaptiveOffset(y: 40)
                        .adaptiveOffset(x: 4)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .adaptiveOffset(x: 6)
        }
    }
    
    // MARK: - Filter Tabs
    
    ///  панель с табами фильтров (Color Picker, Pastel, Bright)
    private var filterTabs: some View {
        ZStack {
            // Background blur panel
            Image("BGColorPicker")
                .resizable()
                .scaledToFit()
            
            
            // Активный индикатор под выбранным табом
            HStack {
                if viewModel.selectedFilterTab == .colorPicker {
                    DugaPath()
                        .stroke(.primColor, style: StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                        .adaptiveFrame(width: 130, height: 46.1)
                        .adaptiveOffset(x: -113)
                    
                } else if viewModel.selectedFilterTab == .pastel {
                    Spacer()
                    VStack(spacing: 46.1) {
                        Rectangle()
                            .fill(.primColor)
                            .adaptiveFrame(height: 2)
                            .adaptiveFrame(width: 88)
                        
                        Rectangle()
                            .fill(.primColor)
                            .adaptiveFrame(height: 2)
                            .adaptiveFrame(width: 88)
                        
                    }
                    Spacer()
                } else {
                    DugaPath()
                        .stroke(.primColor, style: StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                        .adaptiveFrame(width: 130, height: 46.1)
                        .rotationEffect(.degrees(180))
                        .adaptiveOffset(x: 113)
                    
                }
            }
            .padding(.horizontal, 36)
            
            
            // Filter tabs
            
            // Color Picker tab
            Button {
                viewModel.selectFilterTab(.colorPicker)
            } label: {
                Text("COLOR PICKER")
                    .font(Font.custom("DMSans-Regular", size: 12))
                    .kerning(2.04)
                    .foregroundColor(viewModel.selectedFilterTab == .colorPicker ? .primColor : .primColor.opacity(0.4))
                    .textCase(.uppercase)
            }
            .buttonStyle(PlainButtonStyle())
            .adaptiveOffset(x: -100)
            // Pastel tab
            Button {
                viewModel.selectFilterTab(.pastel)
            } label: {
                Text("PASTEL")
                    .font(Font.custom("DMSans-Regular", size: 12))
                    .kerning(2.04)
                    .foregroundColor(viewModel.selectedFilterTab == .pastel ? .primColor : .primColor.opacity(0.4))
                    .textCase(.uppercase)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Bright tab
            Button {
                viewModel.selectFilterTab(.bright)
            } label: {
                Text("BRIGHT")
                    .font(Font.custom("DMSans-Regular", size: 12))
                    .kerning(2.04)
                    .foregroundColor(viewModel.selectedFilterTab == .bright ? .primColor : .primColor.opacity(0.4))
                    .textCase(.uppercase)
            }
            .buttonStyle(PlainButtonStyle())
            .adaptiveOffset(x: 100)
        }
    }
    
    // MARK: - Section Tabs
    
    /// Секционные табы (Section 1, 2, 3)
    private var sectionTabs: some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                // Section 1
                Button {
                    viewModel.selectSection(.section1)
                } label: {
                    Text("SECTION 1")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(viewModel.selectedSection == .section1 ? .primColor : .primColor.opacity(0.6))
                        .textCase(.uppercase)
                        .adaptiveFrame(width: 120)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Section 2
                Button {
                    viewModel.selectSection(.section2)
                } label: {
                    Text("SECTION 2")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(viewModel.selectedSection == .section2 ? .primColor : .primColor.opacity(0.6))
                        .textCase(.uppercase)
                        .adaptiveFrame(width: 120)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Section 3
                Button {
                    viewModel.selectSection(.section3)
                } label: {
                    Text("SECTION 3")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(viewModel.selectedSection == .section3 ? .primColor : .primColor.opacity(0.6))
                        .textCase(.uppercase)
                        .adaptiveFrame(width: 120)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Нижний индикатор и разделитель
            VStack(spacing: 0) {
                // Активный индикатор под выбранным табом
                HStack(spacing: 0) {
                    if viewModel.selectedSection == .section1 {
                        Rectangle()
                            .fill(.primColor)
                            .adaptiveFrame(width: 120, height: 1)
                        Rectangle()
                            .fill(.primColor.opacity(0.3))
                            .adaptiveFrame(width: 255, height: 1)
                    } else if viewModel.selectedSection == .section2 {
                        Rectangle()
                            .fill(.primColor.opacity(0.3))
                            .adaptiveFrame(width: 120, height: 1)
                        Rectangle()
                            .fill(.primColor)
                            .adaptiveFrame(width: 120, height: 1)
                        Rectangle()
                            .fill(.primColor.opacity(0.3))
                            .adaptiveFrame(width: 120, height: 1)
                    } else {
                        Rectangle()
                            .fill(.primColor.opacity(0.3))
                            .adaptiveFrame(width: 240, height: 1)
                        Rectangle()
                            .fill(.primColor)
                            .adaptiveFrame(width: 120, height: 1)
                    }
                }
            }
        }
    }
    
    // MARK: - Scene Grid
    
    /// Сетка с круглыми изображениями природных сцен
    private var sceneGrid: some View {
        ScrollView{
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 19) {
                ForEach(viewModel.currentScenes) { scene in
                    SceneCard(scene: scene) {
                        viewModel.selectScene(scene)
                    } onEdit: {
                        viewModel.editPreset(scene)
                    }
                }
            }
            .padding(.horizontal, 23)
            .padding(.bottom, 350) // Добавляем отступ снизу для TabBar и Safe Area
        }
    }
    
    
    // MARK: - Bulb center
    
    /// Щит с тоглами ламп комнаты
    private var bulbCenterView: some View {
        ZStack {
            VStack {
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(height: 1)
                    .background(Color(red: 0.79, green: 1, blue: 1))
                    .opacity(0.3)
                    .adaptiveOffset(y: 8)
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(height: 220)
                    .background(Color(red: 0.01, green: 0.04, blue: 0.05).opacity(0.92))
                    .shadow(color: .black.opacity(0.25), radius: 7.5, x: 0, y: -1)
            }
            
            Text("BULB CENTER")
                .font(Font.custom("DMSans-Regular", size: 12))
                .kerning(2.5)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .opacity(0.6)
                .textCase(.uppercase)
                .adaptiveOffset(y: -75)
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showBulbTogglesPanel = false
                }
            } label: {
                Image("Minimaze")
                    .resizable()
                    .scaledToFit()
                    .adaptiveFrame(width: 48, height: 48)
            }
            .buttonStyle(PlainButtonStyle())
            .adaptiveOffset(x: 147, y: -75)
            
            // Динамические тоглы ламп
            bulbTogglesContent
        }
    }
    
    /// Контент с тоглами ламп
    private var bulbTogglesContent: some View {
        let roomLights = getRoomLights()
        
        return Group {
            if roomLights.isEmpty {
                Text("НЕТ ЛАМП")
                    .font(Font.custom("DMSans-Regular", size: 12))
                    .kerning(2.04)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .opacity(0.6)
                    .textCase(.uppercase)
            } else if roomLights.count <= 4 {
                // Если ламп 4 или меньше - размещаем в фиксированной сетке
                fixedBulbTogglesGrid(lights: roomLights)
            } else {
                // Если ламп больше 4 - добавляем скролл
                scrollableBulbToggles(lights: roomLights)
            }
        }
    }
    
    /// Фиксированная сетка тоглов (до 4 ламп)
    private func fixedBulbTogglesGrid(lights: [Light]) -> some View {
        VStack(spacing: 16) {
            if lights.count == 1 {
                // Одна лампа в первой позиции (левый верхний угол)
                HStack(spacing: 24) {
                    BulbToggleItem(light: lights[0])
                        .environmentObject(appViewModel)
                    Spacer().adaptiveFrame(width: 80) // Пустое место справа
                }
            } else if lights.count == 2 {
                // Две лампы в первой строке
                BulbToggleRow(lights: Array(lights[0...1]))
            } else if lights.count == 3 {
                // Две лампы в первой строке, одна во второй
                BulbToggleRow(lights: Array(lights[0...1]))
                HStack(spacing: 24) {
                    BulbToggleItem(light: lights[2])
                        .environmentObject(appViewModel)
                    Spacer().adaptiveFrame(width: 80) // Пустое место справа
                }
            } else if lights.count == 4 {
                // Две строки по две лампы
                BulbToggleRow(lights: Array(lights[0...1]))
                BulbToggleRow(lights: Array(lights[2...3]))
            }
        }
    }
    
    /// Скроллируемые тоглы (больше 4 ламп)
    private func scrollableBulbToggles(lights: [Light]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // Размещаем по 2 лампы в строке
                ForEach(0..<(lights.count + 1) / 2, id: \.self) { rowIndex in
                    let startIndex = rowIndex * 2
                    let endIndex = min(startIndex + 1, lights.count - 1)
                    let rowLights = Array(lights[startIndex...endIndex])
                    
                    BulbToggleRow(lights: rowLights)
                }
            }
            .padding(.horizontal, 20)
        }
        .adaptiveFrame(height: 140) // Ограничиваем высоту для скролла
    }
    
    /// Функция для получения ламп комнаты
    private func getRoomLights() -> [Light] {
        guard let targetRoom = nav.targetRoomForColorChange else {
            return []
        }
        
        return appViewModel.lightsViewModel.lights.filter { light in
            targetRoom.lightIds.contains(light.id)
        }
    }
    
    // MARK: - Scene Card
    
    /// Карточка отдельной сцены с круглым изображением
    private struct SceneCard: View {
        let scene: EnvironmentSceneEntity
        let onTap: () -> Void
        let onEdit: () -> Void
        
        var body: some View {
            VStack(spacing: 10) {
                // Круглое изображение сцены
                Button {
                    onTap()
                    onEdit()
                } label: {
                    ZStack {
                        // SVG иконка в центре
                        Image(scene.imageAssetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .adaptiveFrame(width: 156, height: 156)
                            .foregroundColor(.primColor.opacity(0.9))
                        
                        // Overlay для эффекта нажатия
                        if scene.isSelected {
                            Circle()
                                .stroke(.primColor, lineWidth: 3)
                                .adaptiveFrame(width: 156, height: 156)
                        }
                        
                        // Индикатор наличия цветов пресета
                        if scene.hasPresetColors {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    // Показываем небольшие цветные точки в углу
                                    HStack(spacing: 2) {
                                        ForEach(Array(scene.presetColors.prefix(5).enumerated()), id: \.0) { index, presetColor in
                                            Circle()
                                                .fill(presetColor.color)
                                                .adaptiveFrame(width: 12, height: 12)
                                                .overlay(
                                                    Circle()
                                                        .stroke(.primColor.opacity(0.3), lineWidth: 0.5)
                                                )
                                        }
                                    }
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.black.opacity(0.3))
                                    )
                                    .adaptiveOffset(x: 0, y: -8)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                
                // Название сцены
                Text(scene.name.uppercased())
                    .font(Font.custom("DMSans-ExtraLight", size: 12))
                    .kerning(2.04)
                    .foregroundColor(.primColor)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Bulb Toggle Row
    
    /// Строка с тоглами ламп (до 2 ламп в строке)
    private struct BulbToggleRow: View {
        let lights: [Light]
        @EnvironmentObject var appViewModel: AppViewModel
        
        var body: some View {
            HStack(spacing: 24) {
                ForEach(lights, id: \.id) { light in
                    BulbToggleItem(light: light)
                }
            }
        }
    }
    
    // MARK: - Bulb Toggle Item
    
    /// Отдельный тогл лампы с названием
    private struct BulbToggleItem: View {
        let light: Light
        @EnvironmentObject var appViewModel: AppViewModel
        
        var body: some View {
            VStack(spacing: 8) {
                CustomToggleForBulbCenter(
                    isOn: Binding(
                        get: { light.on.on },
                        set: { newValue in
                            toggleLight(newValue)
                        }
                    )
                )
                
                Text(light.metadata.name.uppercased())
                    .font(Font.custom("DM Sans", size: 10))
                    .kerning(1.5)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .opacity(light.isReachable ? 0.6 : 0.3)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .adaptiveFrame(width: 80)
            }
        }
        
        /// Переключает состояние лампы
        private func toggleLight(_ isOn: Bool) {
            appViewModel.lightsViewModel.setPower(for: light, on: isOn)
        }
    }
}
// MARK: - Preview

#Preview("Environment Bulbs View") {
    EnvironmentBulbsView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
}

#Preview("Environment Bulbs with Figma") {
    EnvironmentBulbsView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/7DwY12hUyQ1ruSTx7TWB01/Bulbs_HUE-NEW?node-id=130-4392&t=NNN8510Dw2zKtV1F-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

struct CustomToggleForBulbCenter: View {
    @Binding var isOn: Bool

    var body: some View {
        ZStack {
            // Фон переключателя
            RoundedRectangle(cornerRadius: 100)
                .fill(Color(red: 0.8, green: 0.49, blue: 0.92))
                .adaptiveFrame(width: 72, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                )

            // Круглый переключатель
            Circle()
                .fill(Color.white)
                .adaptiveFrame(width: 28, height: 28)
                .adaptiveOffset(x: isOn ? 51 - 36 : -51 + 36) // смещение по состоянию
                .animation(.easeInOut(duration: 0.2), value: isOn)
        }
        .adaptiveFrame(width: 72, height: 40)
        .onTapGesture {
            isOn.toggle()
        }
    }
}
