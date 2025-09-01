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
    
    var body: some View {
        ZStack {
            // Основной градиентный фон
           BG()
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
        }
        .ignoresSafeArea(.all)
    }
    

    
    // MARK: - Navigation Header
    
    /// Верхняя навигационная панель с кнопками и заголовком
    private var navigationHeader: some View {
        Header(title: "BULB") {
            ChevronButton {
                nav.go(.environment)
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
    }
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
