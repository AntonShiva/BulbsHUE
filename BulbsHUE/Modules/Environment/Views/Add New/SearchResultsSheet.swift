//
//  SearchResultsSheet.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct SearchResultsSheet: View {
    @EnvironmentObject var nav: NavigationManager
    @EnvironmentObject var appViewModel: AppViewModel
    
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
                LazyVStack(spacing: 12) {
                    // Показываем индикатор загрузки при поиске по серийному номеру
                    if nav.searchType == .serialNumber && lightsViewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.79, green: 1, blue: 1)))
                                .scaleEffect(1.2)
                            
                            Text("adding lamp...")
                                .font(Font.custom("DMSans-Light", size: 16))
                                .kerning(2.4)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                .textCase(.uppercase)
                            
                            Text("lamp should flash to confirm reset")
                                .font(Font.custom("DMSans-Light", size: 10))
                                .kerning(1.0)
                                .lineSpacing(2)
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                .opacity(0.7)
                        }
                        .padding(.top, 40)
                    } else {
                        // Показываем разные списки в зависимости от типа поиска
                        ForEach(getLightsToShow()) { light in
                            VStack(alignment: .leading, spacing: 8) {
                                
                                //                                BulbCell(text: light.metadata.name, image: "lightBulb", width: 32, height: 32) {
                                //                                    nav.showCategoriesSelection(for: light)
                                //                                }
                                LightResultCell(
                                    light: light,
                                    onTap: {
                                        // Только при нажатии показываем категории
                                        nav.selectedLight = light
                                        nav.showCategoriesSelection(for: light)
                                    }
                                )
                            }
                        }
                        // После ScrollView добавьте:
                        if getLightsToShow().isEmpty && !lightsViewModel.isLoading {
                            VStack {
                                Text("DEBUG INFO")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text("Lights count: \(lightsViewModel.lights.count)")
                                Text("Network found: \(lightsViewModel.networkFoundLights.count)")
                                Text("Search type: \(nav.searchType == .network ? "Network" : "Serial")")
                                Text("Bridge IP: \(appViewModel.apiClient.bridgeIP)")
                            }
                            .padding()
                        }
                        
//                        // Показываем сообщение если ничего не найдено при поиске по серийнику
//                        if nav.searchType == .serialNumber && lightsViewModel.serialNumberFoundLights.isEmpty && !lightsViewModel.isLoading {
//                            VStack(spacing: 16) {
//                                if let error = lightsViewModel.error {
//                                    // Показываем конкретную ошибку
//                                    Text("connection error")
//                                        .font(Font.custom("DMSans-Light", size: 16))
//                                        .kerning(2.4)
//                                        .foregroundColor(Color.red)
//                                        .textCase(.uppercase)
//                                    
//                                    Text(error.localizedDescription)
//                                        .font(Font.custom("DMSans-Light", size: 10))
//                                        .kerning(1.0)
//                                        .lineSpacing(2)
//                                        .multilineTextAlignment(.center)
//                                        .foregroundColor(Color.red)
//                                        .opacity(0.8)
//                                } else {
//                                    // Стандартное сообщение
//                                    Text("lamp not found")
//                                        .font(Font.custom("DMSans-Light", size: 16))
//                                        .kerning(2.4)
//                                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
//                                        .textCase(.uppercase)
//                                    
//                                    Text("• ensure lamp is within 1m of bridge\n• check serial number (6 characters)\n• make sure lamp is powered on")
//                                        .font(Font.custom("DMSans-Light", size: 10))
//                                        .kerning(1.0)
//                                        .lineSpacing(2)
//                                        .multilineTextAlignment(.center)
//                                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
//                                        .opacity(0.7)
//                                }
//                            }
//                            .padding(.top, 40)
//                        }
                    }
                }
                .padding()
            }
            .adaptiveOffset(y: 285)
        }
        // В SearchResultsSheet.swift, добавьте отладочное сообщение:
        .onAppear {
            print("🔄 SearchResultsSheet появился")
            
            // Добавьте диагностическое сообщение на экран
            if lightsViewModel.lights.isEmpty {
                print("⚠️ Список ламп пуст!")
            }
            
            Task {
                // Запустите диагностику
                lightsViewModel.runSearchDiagnostics { report in
                    print(report)
                    // Можно вывести report на экран для пользователя в Канаде
                }
            }
        }
        .onAppear {
            // Обновляем данные ламп при каждом открытии экрана с принудительным обновлением статуса
            // ✅ НОВОЕ ПОВЕДЕНИЕ: HueAPIClient.updateLightCommunicationStatus теперь обновляет 
            // статус связи в памяти через LightsViewModel для мгновенного отклика UI
            print("🔄 SearchResultsSheet: Обновляем данные ламп с актуальным статусом")
            Task {
                await lightsViewModel.refreshLightsWithStatus()
            }
            
            // Запускаем мониторинг изменений состояния ламп в реальном времени
            print("📡 SearchResultsSheet: Запускаем мониторинг статуса ламп")
            lightsViewModel.startLightStatusMonitoring()
        }
        .onDisappear {
            // Останавливаем мониторинг при закрытии экрана для экономии ресурсов
            print("⏹️ SearchResultsSheet: Останавливаем мониторинг статуса ламп")
            lightsViewModel.stopLightStatusMonitoring()
        }
        .refreshable {
            // Поддержка pull-to-refresh с принудительным обновлением статуса
            print("🔄 SearchResultsSheet: Pull-to-refresh с обновлением статуса")
            await lightsViewModel.refreshLightsWithStatus()
        }
        
    }
    // MARK: - Helper Functions
        private func getLightsToShow() -> [Light] {
            switch nav.searchType {
            case .network:
                // Показываем явные результаты сетевого поиска, если есть
                if !lightsViewModel.networkFoundLights.isEmpty {
                    return lightsViewModel.networkFoundLights
                }
                
                // Если networkFoundLights пустой, показываем ВСЕ лампы из системы
                // чтобы пользователь мог их настроить
                if !lightsViewModel.lights.isEmpty {
                    print("📋 Показываем все доступные лампы: \(lightsViewModel.lights.count)")
                    return lightsViewModel.lights.filter { light in
                        // Показываем лампы которые еще не настроены пользователем
                        let needsConfiguration = light.metadata.userSubtypeName == nil ||
                                               light.metadata.userSubtypeName?.isEmpty == true
                        
                        if needsConfiguration {
                            print("   ✨ Лампа '\(light.metadata.name)' требует настройки")
                        }
                        
                        // Показываем все лампы, даже настроенные (для перенастройки)
                        return true
                    }
                }
                
                // Фоллбек: показываем лампы, которые выглядят как новые
                return lightsViewModel.lights.filter { $0.isNewLight }
                
            case .serialNumber:
                // Показываем результаты поиска по серийному номеру
                if !lightsViewModel.serialNumberFoundLights.isEmpty {
                    return lightsViewModel.serialNumberFoundLights
                }
                // Если поиск еще идет, показываем пустой массив
                return lightsViewModel.isLoading ? [] : lightsViewModel.serialNumberFoundLights
            }
        }
    
    
}

#Preview {
    SearchResultsSheet()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
        .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}

//            // Здесь должен быть список найденных устройств
//            VStack(spacing: 8) {
//                // Пример найденных устройств - в реальности здесь будет ForEach с данными
//                BulbCell(text: "Philips Hue Color", image: "lightBulb", width: 32, height: 32) {
//                    nav.showCategoriesSelection()
//                }
//
//                BulbCell(text: "IKEA TRÅDFRI", image: "lightBulb", width: 32, height: 32) {
//                    nav.showCategoriesSelection()
//                }
//
//                BulbCell(text: "Xiaomi Yeelight", image: "lightBulb", width: 32, height: 32) {
//                    nav.showCategoriesSelection()
//                }
//            }
// Новый компонент для отображения лампы с индикацией статуса
struct LightResultCell: View {
    let light: Light
    let onTap: () -> Void
    
    // Получаем LightsViewModel из Environment
    @EnvironmentObject var appViewModel: AppViewModel
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
