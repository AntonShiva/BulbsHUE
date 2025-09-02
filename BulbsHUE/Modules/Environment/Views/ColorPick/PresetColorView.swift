//
//  PresetColorView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/29/25.
//

import SwiftUI
import Combine

struct PresetColorView: View {
    @EnvironmentObject var nav: NavigationManager
    @StateObject private var viewModel: PresetColorViewModel
    
    // Принимаем сцену для редактирования
    let scene: EnvironmentSceneEntity?
    
    init(scene: EnvironmentSceneEntity? = nil) {
        self.scene = scene
        self._viewModel = StateObject(wrappedValue: PresetColorViewModel(scene: scene))
    }
   
    var body: some View {
        ZStack{
            BG()
            navigationHeader
                .adaptiveOffset(y: -328)
            
            // Добавляем табы
            presetColorTabs
                .adaptiveOffset(y: -262)
            
            ZStack{
                if let scene = scene {
                    // Отображаем изображение выбранной сцены
                    Image(scene.imageAssetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .adaptiveFrame(width: 308, height: 308)
                        .clipped()
                } else {
                    // Fallback для случая без сцены
                    Image("Neon Abyss")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .adaptiveFrame(width: 308, height: 308)
                        .clipped()
                }
                
                Circle()
                    .inset(by: 1)
                    .stroke(Color(red: 0.99, green: 0.98, blue: 0.84), lineWidth: 2)
                    .adaptiveFrame(width: 334, height: 334)
            }
            .adaptiveOffset(y: -39)
            
            // Контент в зависимости от выбранного таба
            selectedTabContent
                .adaptiveOffset(y: viewModel.selectedTab == .statics ? 247 : 258)
        }
    }
    /// Верхняя навигационная панель с кнопками и заголовком
    private var navigationHeader: some View {
        Header(title: scene?.name.uppercased() ?? "SCENE NAME") {
            ChevronButton {
                nav.hidePresetColorEdit()
            }
            .rotationEffect(.degrees(180))
    } leftView2: {
        EmptyView()
    } rightView1: {
        EmptyView()
    } rightView2: {
      
        // Центральная кнопка - FAV
        Button {
            viewModel.toggleFavorite()
        } label: {
            ZStack {
                BGCircle()
                    .adaptiveFrame(width: 48, height: 48)
                
                // Heart icon - показываем состояние избранного из сцены
                Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundColor(.primColor)
               
            }
        }
        .buttonStyle(PlainButtonStyle())
        .adaptiveOffset(x: -3)
    }
    }
    
    // MARK: - Preset Color Tabs
    
    /// Табы для выбора статического или динамического цвета
    private var presetColorTabs: some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                // STATICS tab
                Button {
                    viewModel.selectedTab = .statics
                } label: {
                    Text("STATICS")
                        .font(Font.custom("DM Sans", size: 12))
                        .tracking(2.04)
                        .foregroundColor(viewModel.selectedTab == .statics ? Color(red: 0.99, green: 0.98, blue: 0.84) : Color(red: 0.99, green: 0.98, blue: 0.84).opacity(0.6))
                        .textCase(.uppercase)
                        .frame(width: 187.5)
                }
                .buttonStyle(PlainButtonStyle())
                
                // DYNAMIC tab
                Button {
                    viewModel.selectedTab = .dynamic
                } label: {
                    Text("DYNAMIC")
                        .font(Font.custom("DM Sans", size: 12))
                        .tracking(2.04)
                        .foregroundColor(viewModel.selectedTab == .dynamic ? Color(red: 0.99, green: 0.98, blue: 0.84) : Color(red: 0.99, green: 0.98, blue: 0.84).opacity(0.6))
                        .textCase(.uppercase)
                        .frame(width: 187.5)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Индикатор активной вкладки
            tabIndicator
        }
        .frame(width: 375, height: 25)
    }
    
    /// Индикатор под выбранной вкладкой
    private var tabIndicator: some View {
        HStack(spacing: 0) {
            if viewModel.selectedTab == .statics {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 178, height: 1)
                    .background(Color(red: 0.99, green: 0.98, blue: 0.84))
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 197, height: 1)
                    .background(Color(red: 0.99, green: 0.98, blue: 0.84).opacity(0.3))
            } else {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 197, height: 1)
                    .background(Color(red: 0.99, green: 0.98, blue: 0.84).opacity(0.3))
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 178, height: 1)
                    .background(Color(red: 0.99, green: 0.98, blue: 0.84))
            }
        }
    }
    
    
    // MARK: - Selected Tab Content
    
    /// Контент для выбранной вкладки
    @ViewBuilder
    private var selectedTabContent: some View {
        switch viewModel.selectedTab {
        case .statics:
            staticsContent
        case .dynamic:
            dynamicContent
        }
    }
    
    // MARK: - Statics Content
    
    /// Контент для статических цветов
    private var staticsContent: some View {
        VStack(spacing: 20) {
            // Слайдер яркости
            BrightnessSlider(
                brightness: $viewModel.brightness,
                color: Color(red: 0.99, green: 0.98, blue: 0.84),
                title: "BRIGHTNESS, %"
            )
           
           
        }
    }
    
    // MARK: - Dynamic Content
    
    /// Контент для динамических цветов
    private var dynamicContent: some View {
        VStack {
            BrightnessSlider(
                brightness: $viewModel.dynamicBrightness,
                color: Color(red: 0.99, green: 0.98, blue: 0.84),
                title: "BRIGHTNESS, %"
            )
            .opacity(viewModel.dynamicBrightnessOpacity)
            
            StyleSettingView(
                selectedStyle: $viewModel.selectedStyle,
                isExpanded: $viewModel.isStyleExpanded
            )
            .opacity(viewModel.styleOpacity)
            
            IntensitySettingView(
                intensityType: $viewModel.selectedIntensity,
                isExpanded: $viewModel.isIntensityExpanded
            )
            .opacity(viewModel.intensityOpacity)
            .adaptiveOffset(y: viewModel.isIntensityExpanded ? -70 : 0)
            
        }
    }
    
 
}

enum PresetColorTab: CaseIterable {
    case statics
    case dynamic
}

@MainActor
class PresetColorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: PresetColorTab = .statics
    @Published var brightness: Double = 50.0
    @Published var isFavorite: Bool = false
    
    // Dynamic settings
    @Published var dynamicBrightness: Double = 50.0
    @Published var selectedStyle: StyleType = .classic
    @Published var selectedIntensity: IntensityType = .middle
    @Published var isStyleExpanded: Bool = false
    @Published var isIntensityExpanded: Bool = false
    
    // MARK: - Private Properties
    private let scene: EnvironmentSceneEntity?
    private let environmentScenesUseCase: EnvironmentScenesUseCaseProtocol
    
    // MARK: - Initialization
    
    init(scene: EnvironmentSceneEntity? = nil) {
        self.scene = scene
        self.environmentScenesUseCase = DIContainer.shared.environmentScenesUseCase
        
        // Устанавливаем начальные значения из сцены
        if let scene = scene {
            self.isFavorite = scene.isFavorite
        }
    }
    
    // MARK: - Computed Properties
    
    /// Прозрачность для BrightnessSlider в динамическом режиме
    var dynamicBrightnessOpacity: Double {
        return (isStyleExpanded || isIntensityExpanded) ? 0.02 : 1.0
    }
    
    /// Прозрачность для StyleSettingView
    var styleOpacity: Double {
        return isIntensityExpanded ? 0.02 : 1.0
    }
    
    /// Прозрачность для IntensitySettingView
    var intensityOpacity: Double {
        return isStyleExpanded ? 0.02 : 1.0
    }
    
    // MARK: - Public Methods
    
    /// Переключить статус избранного
    func toggleFavorite() {
        guard let scene = scene else { return }
        
        Task {
            do {
                let updatedScene = try await environmentScenesUseCase.toggleFavorite(sceneId: scene.id)
                await MainActor.run {
                    self.isFavorite = updatedScene.isFavorite
                }
            } catch {
                print("Error toggling favorite: \(error)")
            }
        }
    }
    
    func savePresetColor() {
        switch selectedTab {
        case .statics:
            print("Saving static preset color settings - brightness: \(brightness)%")
        case .dynamic:
            print("Saving dynamic preset color settings:")
            print("- Brightness: \(dynamicBrightness)%")
            print("- Style: \(selectedStyle.displayName)")
            print("- Intensity: \(selectedIntensity.displayName)")
        }
    }
}


#Preview {
    PresetColorView()
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=123-3818&t=gFp2PiVIXvPVfHoZ-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
