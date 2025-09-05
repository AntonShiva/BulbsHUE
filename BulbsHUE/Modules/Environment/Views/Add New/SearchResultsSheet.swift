//
//  SearchResultsSheet.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI
import Combine

struct SearchResultsSheet: View {
    @Environment(NavigationManager.self) private var nav
    @Environment(AppViewModel.self) private var appViewModel
    
    var lightsViewModel: LightsViewModel {
        appViewModel.lightsViewModel
    }
    
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 35,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 35
            )
            .fill(Color(red: 0.02, green: 0.09, blue: 0.13))
            .adaptiveFrame(width: 375, height: 342)
            
            Text("search results")
                .font(Font.custom("DMSans-Light", size: 14))
                .kerning(2.8)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .textCase(.uppercase)
                .adaptiveOffset(y: -130)

            ScrollView {
                LazyVStack {
                                   if nav.searchType == .serialNumber && !lightsViewModel.lights.isEmpty {
                        // ИНСТРУКЦИЯ для пользователя
                        VStack {
                            Text("Find your lamp by tapping each one.\nThe right lamp will respond.")
                                .font(Font.custom("DMSans-Light", size: 11))
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.8))
                        }
                        
                        .padding(.bottom, 5)
                        
                        // Показываем все лампы для выбора
                        ForEach(getLightsToShow()) { light in
                            LightResultCell(
                                light: light,
                                onTap: {
                                    // При нажатии лампа мигает для идентификации
                                    _ = appViewModel.apiClient.identifyLight(id: light.id)
                                        .sink(
                                            receiveCompletion: { _ in },
                                            receiveValue: { success in
                                                if success {
                                                    print("💡 Лампа \(light.metadata.name) мигнула")
                                                }
                                            }
                                        )
                                    
                                    // Сохраняем выбор и переходим к категориям
                                    if let serialNumber = nav.enteredSerialNumber {
                                        appViewModel.apiClient.confirmLightSelection(light, forSerialNumber: serialNumber)
                                    }
                                    
                                    nav.selectedLight = light
                                    nav.showCategoriesSelection(for: light)
                                }
                            )
                        }
                        
                    } else if nav.searchType == .serialNumber && !lightsViewModel.isLoading {
                        // Показываем сообщение об ошибке если лампа не найдена
                        VStack(spacing: 16) {
                            if let error = lightsViewModel.error {
                                Text("lamp not found")
                                    .font(Font.custom("DMSans-Light", size: 16))
                                    .kerning(2.4)
                                    .foregroundColor(Color.red)
                                    .textCase(.uppercase)
                                
                                Text(error.localizedDescription)
                                    .font(Font.custom("DMSans-Light", size: 10))
                                    .kerning(1.0)
                                    .lineSpacing(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Color.red)
                                    .opacity(0.8)
                            }
                        }
                        .padding(.top, 40)
                        
                    } else {
                        // Показываем результаты сетевого поиска
                        ForEach(getLightsToShow()) { light in
                            LightResultCell(
                                light: light,
                                onTap: {
                                    nav.selectedLight = light
                                    nav.showCategoriesSelection(for: light)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .adaptiveOffset(y: 285)
        }
      
        .refreshable {
            // Поддержка pull-to-refresh
            print("🔄 SearchResultsSheet: Pull-to-refresh")
            await lightsViewModel.refreshLightsWithStatus()
        }
    }
    
    // MARK: - Helper Functions
    private func getLightsToShow() -> [Light] {
        let lights: [Light]
        
        switch nav.searchType {
        case .network:
            // Показываем результаты сетевого поиска
            if !lightsViewModel.networkFoundLights.isEmpty {
                lights = lightsViewModel.networkFoundLights
            } else if !lightsViewModel.lights.isEmpty {
                // Показываем все доступные лампы
                print("📋 Показываем все доступные лампы: \(lightsViewModel.lights.count)")
                lights = lightsViewModel.lights
            } else {
                // Фоллбек: показываем лампы, которые выглядят как новые
                lights = lightsViewModel.lights.filter { $0.isNewLight }
            }
            
        case .serialNumber:
            // Для serial search всегда показываем ВСЕ доступные лампы
            print("📋 Serial search: показываем все лампы для выбора: \(lightsViewModel.lights.count)")
            lights = lightsViewModel.lights
        }
        
        // 🔌 СОРТИРОВКА: Сначала подключенные к электросети, потом неподключенные
        return lights.sorted { first, second in
            // Сначала идут подключенные лампы (isReachable = true)
            if first.isReachable && !second.isReachable {
                return true  // first (подключенная) должна быть выше
            } else if !first.isReachable && second.isReachable {
                return false // second (подключенная) должна быть выше
            } else {
                // Если обе в одинаковом состоянии - сортируем по имени
                return first.metadata.name.localizedCaseInsensitiveCompare(second.metadata.name) == .orderedAscending
            }
        }
    }
}

#Preview {
    SearchResultsSheet()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
        .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}

struct LightResultCell: View {
    let light: Light
    let onTap: () -> Void
    
    // Получаем LightsViewModel из Environment
    @Environment(AppViewModel.self) private var appViewModel
    var lightsViewModel: LightsViewModel {
        appViewModel.lightsViewModel
    }
    
    var body: some View {
        // ✅ ИСПОЛЬЗОВАНИЕ СТАТУСА СВЯЗИ: effectiveState и isReachable учитывают
        // CommunicationStatus который обновляется в реальном времени через HueAPIClient
        let effectiveState = light.effectiveState
        let isReachable = light.isReachable
        let effectiveBrightness = light.effectiveBrightness
        
        HStack(spacing: 12) {
            // Иконка лампы с индикацией включения
            ZStack {
                Image("lightBulb")
                    .resizable()
                    .scaledToFit()
                    .adaptiveFrame(width: 32, height: 32)
                    .foregroundColor(effectiveState.on ? .yellow : .gray)
                
                // Индикатор питания
                if effectiveState.on {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .offset(x: 12, y: -12)
                }
                
                // Индикатор недоступности
                if !isReachable {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: -12, y: 12)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(light.metadata.name)
                    .font(Font.custom("DMSans-Regular", size: 14))
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .textCase(.uppercase)
                
                // Статус питания с учетом доступности
                HStack(spacing: 4) {
                    Circle()
                        .fill(getStatusColor(isReachable: isReachable, isOn: effectiveState.on))
                        .frame(width: 6, height: 6)
                    
                    Text(getStatusText(isReachable: isReachable, isOn: effectiveState.on))
                        .font(Font.custom("DMSans-Light", size: 10))
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.7))
                }
                
                // Показываем яркость если включена и доступна
                if effectiveState.on && isReachable {
                    Text("Яркость: \(Int(effectiveBrightness))%")
                        .font(Font.custom("DMSans-Light", size: 10))
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.5))
                }
            }
            
            Spacer()
            
            ChevronButton {
                onTap()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 332, height: 64)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(15)
                .opacity(effectiveState.on && isReachable ? 0.15 : 0.08) // Более яркий фон для включенных и доступных
        )
        .onTapGesture {
            // При нажатии на ячейку лампы мигаем лампой для визуального подтверждения
            lightsViewModel.blinkLight(light)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStatusColor(isReachable: Bool, isOn: Bool) -> Color {
        if !isReachable {
            return Color.orange // Недоступна
        }
        return isOn ? Color.green : Color.red
    }
    
    private func getStatusText(isReachable: Bool, isOn: Bool) -> String {
        if !isReachable {
            return "Недоступна"
        }
        return isOn ? "Включена" : "Выключена"
    }
}
#Preview {
   
    LightResultCell(
        light: Light(),
        onTap: {
           
        }
    )
    .background(.black)
    
}
