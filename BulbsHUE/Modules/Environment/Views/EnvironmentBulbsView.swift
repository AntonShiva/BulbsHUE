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
             navigationHeader
                .adaptiveOffset(y: -329)
            
            // Blur панель с табами фильтров
            filterTabs
                .adaptiveOffset(y: -240)
            
            // Секционные табы
            sectionTabs
                .adaptiveOffset(y: -179)
            
            // Сетка изображений сцен
            sceneGrid
                .adaptiveOffset(y: 262)
        }
        .ignoresSafeArea(.all)
    }
    

    
    // MARK: - Navigation Header
    
    /// Верхняя навигационная панель с кнопками и заголовком
    private var navigationHeader: some View {
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
        VStack(spacing: 10) {
            // Круглое изображение сцены
            Button(action: onTap) {
                ZStack {
                    // Создаем красивый градиентный фон для SVG иконок
                 
                    
                    // SVG иконка в центре
                    Image(scene.imageURL)
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
