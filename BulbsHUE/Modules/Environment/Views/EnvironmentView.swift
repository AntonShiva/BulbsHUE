//
//  EnvironmentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var dataPersistenceService: DataPersistenceService
    
    /// Специализированная ViewModel для экрана Environment
    @State private var environmentViewModel: EnvironmentViewModel?
    
    var body: some View {
        ZStack {
            BG()
            
            Header(title: "ENVIRONMENT") {
                // Левая кнопка - ваше меню
                MenuButton { }
            } rightView: {
                // Правая кнопка - плюс
                AddHeaderButton {
                    nav.go(.addNewBulb)
                }
            }
            .adaptiveOffset(y: -330)
            
            SelectorTabEnviromentView()
                .adaptiveOffset(y: -264)
            
            // Используем данные из EnvironmentViewModel с персистентным хранением
            if let viewModel = environmentViewModel {
                if !viewModel.hasAssignedLights {
                    EmptyLightsView {
                        nav.go(.addNewBulb)
                    }
                } else {
                    AssignedLightsListView(
                        lights: viewModel.assignedLights,
                        onRemoveLight: { lightId in
                            viewModel.removeLightFromEnvironment(lightId)
                        }
                    )
                    .adaptiveOffset(y: 30)
                }
             }
        }
        .onAppear {
            // Создаем ViewModel с обоими сервисами
            if environmentViewModel == nil {
                environmentViewModel = EnvironmentViewModel(
                    appViewModel: appViewModel,
                    dataPersistenceService: dataPersistenceService
                )
            }
        }
        .refreshable {
            // Поддержка pull-to-refresh
            environmentViewModel?.refreshLights()
        }
    }
}

// MARK: - Subviews

/// Компонент для отображения пустого состояния
private struct EmptyLightsView: View {
    let onAddBulb: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("You don't have \nany bulbs yet")
                .font(Font.custom("DMSans-Regular", size: 16))
                .kerning(3.2)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.75, green: 0.85, blue: 1))
                .opacity(0.3)
                .textCase(.uppercase)

            AddButton(text: "add bulb", width: 427, height: 295) {
                onAddBulb()
            }
            .adaptiveOffset(y: 175)
        }
    }
}

/// Компонент для отображения списка назначенных ламп
private struct AssignedLightsListView: View {
    let lights: [Light]
    let onRemoveLight: ((String) -> Void)?
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                ForEach(lights) { light in
                    ItemControl(light: light)
                        .contextMenu {
                            Button("Убрать из Environment", role: .destructive) {
                                onRemoveLight?(light.id)
                            }
                        }
                }
            }
        }
        .adaptiveOffset(y: 180)
    }
}

#Preview {
    EnvironmentView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .environmentObject(DataPersistenceService.createMock())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=120-1187&t=B04C893qA3iLYnq6-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

#Preview {
    MasterView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .environmentObject(DataPersistenceService.createMock())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=B04C893qA3iLYnq6-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}


