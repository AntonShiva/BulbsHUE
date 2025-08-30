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
    @StateObject private var viewModel = PresetColorViewModel()
   
    var body: some View {
        ZStack{
            BG()
            navigationHeader
                .adaptiveOffset(y: -328)
            
            // Добавляем табы
            presetColorTabs
                .adaptiveOffset(y: -250)
            
            ZStack{
                Image("Neon Abyss")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .adaptiveFrame(width: 308, height: 308)
                    .clipped()
                
                Circle()
                    .inset(by: 1)
                    .stroke(Color(red: 0.99, green: 0.98, blue: 0.84), lineWidth: 2)
                    .frame(width: 334, height: 334)
            }
            .adaptiveOffset(y: -37)
            
            // Контент в зависимости от выбранного таба
            selectedTabContent
                .adaptiveOffset(y: 250)
        }
    }
    /// Верхняя навигационная панель с кнопками и заголовком
    private var navigationHeader: some View {
        Header(title: "SHENE NAME") {
            ChevronButton {
                nav.go(.environment)
            }
            .rotationEffect(.degrees(180))
    } leftView2: {
        EmptyView()
    } rightView1: {
        EmptyView()
    } rightView2: {
      
        // Центральная кнопка - FAV
        Button {
            
        } label: {
            ZStack {
                BGCircle()
                    .adaptiveFrame(width: 48, height: 48)
                
                // Heart icon
                Image(systemName:  "heart")
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
        VStack(spacing: 20) {
            // Множественные слайдеры яркости для разных ламп
            MultipleBrightnessSliders()
            
           
        }
    }
    
 
}

enum PresetColor: CaseIterable {
    case statics
    case dynamic
}

@MainActor
class PresetColorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: PresetColor = .statics
    @Published var brightness: Double = 50.0
    
    // MARK: - Public Methods
    
    func savePresetColor() {
        // Здесь будет логика сохранения настроек пресетного цвета
        print("Saving preset color settings for tab: \(selectedTab), brightness: \(brightness)%")
    }
}


#Preview {
    PresetColorView()
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=123-2559&t=2MO1qF5YMTp0ngJy-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
