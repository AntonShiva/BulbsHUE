//
//  EnvironmentBulbsView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on [DATE].
//

import SwiftUI
import Combine

// MARK: - EnvironmentBulbsView

/// Экран выбора окружающих сцен освещения
/// Отображает коллекцию природных сцен для настройки освещения
struct EnvironmentBulbsView: View {
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var appViewModel: AppViewModel
    
    /// ViewModel для управления состоянием экрана
    @StateObject private var viewModel = EnvironmentBulbsViewModel()
    
    var body: some View {
        ZStack {
            // Основной градиентный фон
           BG()
            
            Header(title: "BULB") {
                ChevronButton {
                   
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
                        Image(systemName: viewModel.isFavoriteFilterActive ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primColor)
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
                    
                    // Bulb icon
                    Image(systemName: viewModel.isMainLightOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primColor)
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
                    
                    // Sun icon
                    Image(systemName: viewModel.isSunModeActive ? "sun.max.fill" : "sun.max")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primColor)
                }
            }
            .buttonStyle(PlainButtonStyle())
                .adaptiveOffset(x: 6)
        }
         

                .adaptiveOffset(y: -327)
            
            // Blur панель с табами фильтров
            filterTabs
                .adaptiveOffset(y: -237)
            
            // Секционные табы
            sectionTabs
                .adaptiveOffset(y: -182)
            
            // Сетка изображений сцен
            sceneGrid
                .adaptiveOffset(y: 260)
        }
        .ignoresSafeArea(.all)
    }
    
    // MARK: - Background
    
    /// Градиентный фон в стиле дизайна
    private var backgroundGradient: some View {
        ZStack {
            // Основной темный фон
            Color(red: 0.024, green: 0.027, blue: 0.027) // #060707
            
            // Размытые эллипсы для создания градиента как в дизайне
            Group {
                // Бирюзовый эллипс слева сверху
                Ellipse()
                    .fill(Color(red: 0, green: 0.8, blue: 0.82))
                    .frame(width: 300, height: 400)
                    .offset(x: -120, y: -300)
                    .blur(radius: 150)
                
                // Синий эллипс справа сверху  
                Ellipse()
                    .fill(Color(red: 0.2, green: 0.3, blue: 0.8))
                    .frame(width: 280, height: 350)
                    .offset(x: 150, y: -250)
                    .blur(radius: 180)
                
                // Фиолетовый эллипс снизу
                Ellipse()
                    .fill(Color(red: 0.4, green: 0.2, blue: 0.9))
                    .frame(width: 350, height: 200)
                    .offset(x: 50, y: 400)
                    .blur(radius: 200)
            }
        }
        .ignoresSafeArea(.all)
    }
    
    /// Тени из дизайна Figma для создания атмосферы
    private var shadowsOverlay: some View {
        // Используем существующий компонент с shadows или создаем аналогичный эффект
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.3)],
                    center: .center,
                    startRadius: 100,
                    endRadius: 400
                )
            )
            .ignoresSafeArea(.all)
    }
    
    // MARK: - Navigation Header
    
    /// Верхняя навигационная панель с кнопками и заголовком
    private var navigationHeader: some View {
        VStack(spacing: 12) {
            // Основная панель с кнопками
            HStack {
                // Левая кнопка - Назад
                Button {
                    nav.back()
                } label: {
                    ZStack {
                        BGCircle()
                            .adaptiveFrame(width: 48, height: 48)
                        
                        // Стрелка назад
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Центральная кнопка - FAV
                Button {
                    viewModel.toggleFavoriteFilter()
                } label: {
                    ZStack {
                        BGCircle()
                            .adaptiveFrame(width: 48, height: 48)
                        
                        // Heart icon
                        Image(systemName: viewModel.isFavoriteFilterActive ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Правая кнопка - Brightness/On
                Button {
                    viewModel.toggleMainLight()
                } label: {
                    ZStack {
                        BGCircle()
                            .adaptiveFrame(width: 48, height: 48)
                        
                        // Bulb icon
                        Image(systemName: viewModel.isMainLightOn ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Дальняя правая кнопка - Sun/Settings
                Button {
                    viewModel.toggleSunMode()
                } label: {
                    ZStack {
                        BGCircle()
                            .adaptiveFrame(width: 48, height: 48)
                        
                        // Sun icon
                        Image(systemName: viewModel.isSunModeActive ? "sun.max.fill" : "sun.max")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            
            // Заголовок BULB и статусы
            HStack {
                VStack(spacing: 4) {
                    Text("FAV")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(.primColor)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("BULB")
                        .font(Font.custom("DMSans-Light", size: 16))
                        .kerning(4)
                        .foregroundColor(.primColor)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("ON")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(.primColor)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("50%")
                        .font(Font.custom("DMSans-Regular", size: 12))
                        .kerning(2.04)
                        .foregroundColor(.primColor)
                        .textCase(.uppercase)
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Filter Tabs
    
    /// Blur панель с табами фильтров (Color Picker, Pastel, Bright)
    private var filterTabs: some View {
        ZStack {
            // Background blur panel
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.2))
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primColor.opacity(0.2), lineWidth: 2)
                )
                .padding(.horizontal, 8)
            
            // Активный индикатор под выбранным табом
            HStack {
                if viewModel.selectedFilterTab == .colorPicker {
                    Rectangle()
                        .fill(.primColor)
                        .frame(height: 2)
                        .frame(width: 88)
                    Spacer()
                } else if viewModel.selectedFilterTab == .pastel {
                    Spacer()
                    Rectangle()
                        .fill(.primColor)
                        .frame(height: 2)
                        .frame(width: 88)
                    Spacer()
                } else {
                    Spacer()
                    Rectangle()
                        .fill(.primColor)
                        .frame(height: 2)
                        .frame(width: 88)
                }
            }
            .padding(.horizontal, 36)
            .offset(y: 23)
            
            // Filter tabs
            HStack(spacing: 44) {
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
            }
        }
    }
    
    // MARK: - Section Tabs
    
    /// Секционные табы (Section 1, 2, 3)
    private var sectionTabs: some View {
        VStack(spacing: 12) {
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
                        .frame(width: 120)
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
                        .frame(width: 120)
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
                        .frame(width: 120)
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
                            .frame(width: 120, height: 1)
                        Rectangle()
                            .fill(.primColor.opacity(0.3))
                            .frame(width: 255, height: 1)
                    } else if viewModel.selectedSection == .section2 {
                        Rectangle()
                            .fill(.primColor.opacity(0.3))
                            .frame(width: 120, height: 1)
                        Rectangle()
                            .fill(.primColor)
                            .frame(width: 120, height: 1)
                        Rectangle()
                            .fill(.primColor.opacity(0.3))
                            .frame(width: 120, height: 1)
                    } else {
                        Rectangle()
                            .fill(.primColor.opacity(0.3))
                            .frame(width: 240, height: 1)
                        Rectangle()
                            .fill(.primColor)
                            .frame(width: 120, height: 1)
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
        ], spacing: 40) {
            ForEach(viewModel.currentScenes) { scene in
                SceneCard(scene: scene) {
                    viewModel.selectScene(scene)
                }
            }
        }
        .padding(.horizontal, 23)
    }
    }
}

// MARK: - Scene Card

/// Карточка отдельной сцены с круглым изображением
private struct SceneCard: View {
    let scene: EnvironmentScene
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Круглое изображение сцены
            Button(action: onTap) {
                ZStack {
                    // Создаем красивый градиентный фон для SVG иконок
                 
                    
                    // SVG иконка в центре
                    Image(scene.imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 156, height: 156)
                        .foregroundColor(.primColor.opacity(0.9))
                    
                    // Overlay для эффекта нажатия
                    if scene.isSelected {
                        Circle()
                            .stroke(.primColor, lineWidth: 3)
                            .frame(width: 156, height: 156)
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

// MARK: - ViewModel

/// ViewModel для управления состоянием экрана EnvironmentBulbs
@MainActor
class EnvironmentBulbsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedFilterTab: FilterTab = .pastel
    @Published var selectedSection: Section = .section1
    @Published var isFavoriteFilterActive = false
    @Published var isMainLightOn = true
    @Published var isSunModeActive = false
    @Published var scenes: [EnvironmentScene] = []
    
    // MARK: - Computed Properties
    
    /// Сцены для текущего выбранного фильтра и секции
    var currentScenes: [EnvironmentScene] {
        return scenes.filter { scene in
            scene.section == selectedSection &&
            scene.filterType == selectedFilterTab &&
            (!isFavoriteFilterActive || scene.isFavorite)
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadMockScenes()
    }
    
    // MARK: - Public Methods
    
    func selectFilterTab(_ tab: FilterTab) {
        selectedFilterTab = tab
    }
    
    func selectSection(_ section: Section) {
        selectedSection = section
    }
    
    func toggleFavoriteFilter() {
        isFavoriteFilterActive.toggle()
    }
    
    func toggleMainLight() {
        isMainLightOn.toggle()
    }
    
    func toggleSunMode() {
        isSunModeActive.toggle()
    }
    
    func selectScene(_ scene: EnvironmentScene) {
        // Снять выделение с всех сцен
        for index in scenes.indices {
            scenes[index].isSelected = false
        }
        
        // Выбрать нужную сцену
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[index].isSelected = true
        }
    }
    
    // MARK: - Private Methods
    
    /// Загрузить mock данные сцен с использованием локальных иконок
    private func loadMockScenes() {
        scenes = [
            // Section 1 - Pastel (используем локальные SVG иконки)
            EnvironmentScene(
                id: "scene1",
                name: "Golden Haze",
                imageURL: "Golden Haze", // Используем локальные ассеты
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene2", 
                name: "Dawn Dunes",
                imageURL: "Dawn Dunes",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene3",
                name: "Whispering Sands",
                imageURL: "Whispering Sands", 
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene4",
                name: "Echoed Patterns",
                imageURL: "Echoed Patterns",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene5",
                name: "Fading Blossoms",
                imageURL: "Fading Blossoms",
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene6",
                name: "Luminous Drift",
                imageURL: "Luminous Drift",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene7",
                name: "Skybound Serenity",
                imageURL: "Skybound Serenity",
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene8",
                name: "Horizon Glow",
                imageURL: "Horizon Glow",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene9",
                name: "Ethereal Metropolis",
                imageURL: "Ethereal Metropolis",
                section: .section1,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene10",
                name: "Verdant Mist", 
                imageURL: "Verdant Mist",
                section: .section1,
                filterType: .pastel,
                isFavorite: false
            ),
            
            // Section 2 - Pastel
            EnvironmentScene(
                id: "scene17",
                name: "Celestial Whispers",
                imageURL: "Celestial Whispers",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene18",
                name: "Silent Ridges",
                imageURL: "Silent Ridges",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene19",
                name: "Soaring Shadows",
                imageURL: "Soaring Shadows",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene20",
                name: "Tranquil Shoreline",
                imageURL: "Tranquil Shoreline",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene21",
                name: "Gilded Glow",
                imageURL: "Gilded Glow",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene22",
                name: "Midnight Echo",
                imageURL: "Midnight Echo",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene23",
                name: "Evergreen Veil",
                imageURL: "Evergreen Veil",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene24",
                name: "Mirror Lake",
                imageURL: "Mirror Lake",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene25",
                name: "Aurora Pulse",
                imageURL: "Aurora Pulse",
                section: .section2,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene26",
                name: "Whispering Wilds",
                imageURL: "Whispering Wilds",
                section: .section2,
                filterType: .pastel,
                isFavorite: false
            ),
            
            // Section 3 - Pastel
            EnvironmentScene(
                id: "scene27",
                name: "Violet Mist",
                imageURL: "Violet Mist",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene28",
                name: "Lavender Horizon",
                imageURL: "Lavender Horizon",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene29",
                name: "Azure Peaks",
                imageURL: "Azure Peaks",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene30",
                name: "Frozen Veins",
                imageURL: "Frozen Veins",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene31",
                name: "Crystal Drift",
                imageURL: "Crystal Drift",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene32",
                name: "Eclipsed Glow",
                imageURL: "Eclipsed Glow",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene33",
                name: "Twilight Pines",
                imageURL: "Twilight Pines",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene34",
                name: "Phantom Summits",
                imageURL: "Phantom Summits",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene35",
                name: "Layered Tranquility",
                imageURL: "Layered Tranquility",
                section: .section3,
                filterType: .pastel,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene36",
                name: "Echoed Fog",
                imageURL: "Echoed Fog",
                section: .section3,
                filterType: .pastel,
                isFavorite: false
            ),
            
            // Section 1 - Color Picker
            EnvironmentScene(
                id: "scene53",
                name: "Bright Red",
                imageURL: "re1",
                section: .section1,
                filterType: .colorPicker,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene54",
                name: "Ocean Blue", 
                imageURL: "re2",
                section: .section1,
                filterType: .colorPicker,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene55",
                name: "Forest Green",
                imageURL: "re3",
                section: .section1,
                filterType: .colorPicker,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene56",
                name: "Sunset Orange",
                imageURL: "re4",
                section: .section1,
                filterType: .colorPicker,
                isFavorite: false
            ),
            
            // Section 1 - Bright
            EnvironmentScene(
                id: "scene57",
                name: "Golden Horizon",
                imageURL: "Golden Horizon",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene58",
                name: "Velvet Glow",
                imageURL: "Velvet Glow",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene59",
                name: "Rosé Quartz",
                imageURL: "Rosé Quartz",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene60",
                name: "Crimson Lanterns",
                imageURL: "Crimson Lanterns",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene61",
                name: "Molten Ember",
                imageURL: "Molten Ember",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene62",
                name: "Canyon Echo",
                imageURL: "Canyon Echo",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene63",
                name: "Lemon Mirage",
                imageURL: "Lemon Mirage",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene64",
                name: "Wild Bloom",
                imageURL: "Wild Bloom",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene65",
                name: "Solar Flare",
                imageURL: "Solar Flare",
                section: .section1,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene66",
                name: "Honey Drip",
                imageURL: "Honey Drip",
                section: .section1,
                filterType: .bright,
                isFavorite: false
            ),
            
            // Section 2 - Bright
            EnvironmentScene(
                id: "scene67",
                name: "Emerald Veil",
                imageURL: "Emerald Veil",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene68",
                name: "Jade Fracture",
                imageURL: "Jade Fracture",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene69",
                name: "Lucky Charm",
                imageURL: "Lucky Charm",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene70",
                name: "Verdant Passage",
                imageURL: "Verdant Passage",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene71",
                name: "Geometric Mirage",
                imageURL: "Geometric Mirage",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene72",
                name: "Lego Labyrinth",
                imageURL: "Lego Labyrinth",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene73",
                name: "Citrus Harvest",
                imageURL: "Citrus Harvest",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene74",
                name: "Neon Zest",
                imageURL: "Neon Zest",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene75",
                name: "Aurora Echo",
                imageURL: "Aurora Echo",
                section: .section2,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene76",
                name: "Celestial Glow",
                imageURL: "Celestial Glow",
                section: .section2,
                filterType: .bright,
                isFavorite: false
            ),
            
            // Section 3 - Bright
            EnvironmentScene(
                id: "scene77",
                name: "Neon Abyss",
                imageURL: "Neon Abyss",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene78",
                name: "Blooming Depths",
                imageURL: "Blooming Depths",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene79",
                name: "Serene Waves",
                imageURL: "Serene Waves",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene80",
                name: "Crystal Tide",
                imageURL: "Crystal Tide",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene81",
                name: "Twilight Bloom",
                imageURL: "Twilight Bloom",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene82",
                name: "Phantom Drift",
                imageURL: "Phantom Drift",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene83",
                name: "Nebula Mirage",
                imageURL: "Nebula Mirage",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene84",
                name: "Lunar Medusa",
                imageURL: "Lunar Medusa",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            ),
            EnvironmentScene(
                id: "scene85",
                name: "Sapphire Glow",
                imageURL: "Sapphire Glow",
                section: .section3,
                filterType: .bright,
                isFavorite: true
            ),
            EnvironmentScene(
                id: "scene86",
                name: "Frozen Whispers",
                imageURL: "Frozen Whispers",
                section: .section3,
                filterType: .bright,
                isFavorite: false
            )
        ]
    }
}

// MARK: - Data Models

/// Модель сцены окружения
struct EnvironmentScene: Identifiable {
    let id: String
    let name: String
    let imageURL: String
    let section: Section
    let filterType: FilterTab
    let isFavorite: Bool
    var isSelected: Bool = false
}

/// Типы фильтров
enum FilterTab: CaseIterable {
    case colorPicker
    case pastel  
    case bright
}

/// Секции
enum Section: CaseIterable {
    case section1
    case section2
    case section3
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
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=120-2042&m=dev")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
