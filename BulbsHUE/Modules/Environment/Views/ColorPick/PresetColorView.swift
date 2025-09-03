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
        let mainColor = scene?.primaryColor ?? .defaultUIColor
        ZStack{
            BGLight()
            BGTop()
            navigationHeader(mainColor: mainColor)
                .adaptiveOffset(y: -328)
            // Добавляем табы
            presetColorTabs(mainColor: mainColor)
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
                if let scene = scene {
                // Индикатор наличия цветов пресета
                if scene.hasPresetColors {
                   
                            // Показываем небольшие цветные точки в углу
                            HStack(spacing: 2) {
                                ForEach(Array(scene.presetColors.prefix(5).enumerated()), id: \.0) { index, presetColor in
                                    Circle()
                                        .fill(presetColor.color)
                                        .adaptiveFrame(width: 18, height: 18)
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
                            .adaptiveOffset( y: 200)
                 
                }
            }
                Circle()
                    .inset(by: 1)
                    .stroke(mainColor, lineWidth: 2)
                    .adaptiveFrame(width: 334, height: 334)
            }
            .adaptiveOffset(y: -39)
            // Контент в зависимости от выбранного таба
            selectedTabContent(mainColor: mainColor)
                .adaptiveOffset(y: viewModel.selectedTab == .statics ? 247 : 258)
        }
    }
    /// Верхняя навигационная панель с кнопками и заголовком
    private func navigationHeader(mainColor: Color) -> some View {
        HeaderPreset(title: scene?.name.uppercased() ?? "SCENE NAME", mainColor: mainColor) {
            ChevronButtonPreset(mainColor: mainColor) {
                nav.hidePresetColorEdit()
            }
            .rotationEffect(.degrees(180))
            .foregroundColor(mainColor)
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
                    Circle()
                        .stroke(mainColor.opacity(0.2), lineWidth: 2.2)
                        .adaptiveFrame(width: 48, height: 48)
                    // Heart icon - показываем состояние избранного из сцены
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundColor(mainColor)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .adaptiveOffset(x: -3)
        }
    }
    
    // MARK: - Preset Color Tabs
    
    /// Табы для выбора статического или динамического цвета
    private func presetColorTabs(mainColor: Color) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                // STATICS tab
                Button {
                    viewModel.selectedTab = .statics
                } label: {
                    Text("STATICS")
                        .font(Font.custom("DM Sans", size: 12))
                        .tracking(2.04)
                        .foregroundColor(viewModel.selectedTab == .statics ? mainColor : mainColor.opacity(0.6))
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
                        .foregroundColor(viewModel.selectedTab == .dynamic ? mainColor : mainColor.opacity(0.6))
                        .textCase(.uppercase)
                        .frame(width: 187.5)
                }
                .buttonStyle(PlainButtonStyle())
            }
            // Индикатор активной вкладки
            tabIndicator(mainColor: mainColor)
        }
        .frame(width: 375, height: 25)
    }
    
    /// Индикатор под выбранной вкладкой
    private func tabIndicator(mainColor: Color) -> some View {
        HStack(spacing: 0) {
            if viewModel.selectedTab == .statics {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 178, height: 1)
                    .background(mainColor)
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 197, height: 1)
                    .background(mainColor.opacity(0.3))
            } else {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 197, height: 1)
                    .background(mainColor.opacity(0.3))
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 178, height: 1)
                    .background(mainColor)
            }
        }
    }
    
    
    // MARK: - Selected Tab Content
    
    /// Контент для выбранной вкладки
    @ViewBuilder
    private func selectedTabContent(mainColor: Color) -> some View {
        switch viewModel.selectedTab {
        case .statics:
            staticsContent(mainColor: mainColor)
        case .dynamic:
            dynamicContent(mainColor: mainColor)
        }
    }
    
    // MARK: - Statics Content
    
    /// Контент для статических цветов
    private func staticsContent(mainColor: Color) -> some View {
        VStack(spacing: 20) {
            // Слайдер яркости
            BrightnessSlider(
                brightness: $viewModel.brightness,
                color: mainColor,
                title: "BRIGHTNESS, %"
            )
        }
    }
    
    // MARK: - Dynamic Content
    
    /// Контент для динамических цветов
    private func dynamicContent(mainColor: Color) -> some View {
        VStack {
            BrightnessSlider(
                brightness: $viewModel.dynamicBrightness,
                color: mainColor,
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
struct ChevronButtonPreset: View {
    var mainColor: Color
    var action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .stroke(mainColor.opacity(0.2), lineWidth: 2.2)
                    .adaptiveFrame(width: 47, height: 47)
                     
                     Image(systemName: "chevron.right")
                    .font(.system(size: 16)).fontWeight(.bold)
                         .foregroundColor(mainColor)
                 }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HeaderPreset<LeftView1: View,LeftView2: View, RightView1: View,RightView2: View>: View {
   var title: String
    var mainColor: Color
    @ViewBuilder let leftView1: LeftView1
    @ViewBuilder let leftView2: LeftView2
    @ViewBuilder let rightView1: RightView1
    @ViewBuilder let rightView2: RightView2
    
    var body: some View {
        ZStack {
            // Левая кнопка
            leftView1
                .adaptiveOffset(x: -140)
            leftView2
                .adaptiveOffset(x: -83)
            // Заголовок по центру
            Text(title)
                .font(Font.custom("DMSans-Regular", size: 16))
                .kerning(4.3)
                .foregroundColor(mainColor)
              .blur(radius: 0.2)
            
            rightView1
                .adaptiveOffset(x: 91)
           // Правая кнопка
            rightView2
                .adaptiveOffset(x: 142)
        }
     }
}
