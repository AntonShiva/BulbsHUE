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
                                if nav.searchType == .serialNumber {
                                    // Для добавления по серийному номеру показываем информацию о новой лампе
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("lamp added successfully")
                                            .font(Font.custom("DMSans-Light", size: 12))
                                            .kerning(1.8)
                                            .foregroundColor(Color.green)
                                            .textCase(.uppercase)
                                            .opacity(0.8)
                                        
                                        Text("ready to assign category and type")
                                            .font(Font.custom("DMSans-Light", size: 10))
                                            .kerning(1.0)
                                            .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                            .opacity(0.7)
                                    }
                                    .padding(.bottom, 4)
                                }
                                
                                BulbCell(text: light.metadata.name, image: "lightBulb", width: 32, height: 32) {
                                    nav.showCategoriesSelection(for: light)
                                }
                            }
                        }
                        
                        // Показываем сообщение если ничего не найдено при поиске по серийнику
                        if nav.searchType == .serialNumber && lightsViewModel.serialNumberFoundLights.isEmpty && !lightsViewModel.isLoading {
                            VStack(spacing: 16) {
                                if let error = lightsViewModel.error {
                                    // Показываем конкретную ошибку
                                    Text("connection error")
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
                                } else {
                                    // Стандартное сообщение
                                    Text("lamp not found")
                                        .font(Font.custom("DMSans-Light", size: 16))
                                        .kerning(2.4)
                                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                        .textCase(.uppercase)
                                    
                                    Text("• ensure lamp is within 1m of bridge\n• check serial number (6 characters)\n• make sure lamp is powered on")
                                        .font(Font.custom("DMSans-Light", size: 10))
                                        .kerning(1.0)
                                        .lineSpacing(2)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                        .opacity(0.7)
                                }
                            }
                            .padding(.top, 40)
                        }
                    }
                }
                .padding()
            }
            .adaptiveOffset(y: 285)
        }
        
    }
    
    // MARK: - Helper Functions
    private func getLightsToShow() -> [Light] {
        switch nav.searchType {
        case .network:
            return lightsViewModel.lights
        case .serialNumber:
            return lightsViewModel.serialNumberFoundLights
        }
    }
}

#Preview {
    SearchResultsSheet()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
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
