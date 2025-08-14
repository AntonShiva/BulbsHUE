//
//  SelectСategoriesSheet.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 05.08.2025.
//

import SwiftUI

struct SelectCategoriesSheet: View {
    @EnvironmentObject var nav: NavigationManager
    @StateObject private var typeManager = BulbTypeManager()
    @State private var selectedBulbType: BulbType?
    
    var body: some View {
        ZStack {
            // Основной фон
            UnevenRoundedRectangle(
                topLeadingRadius: 35,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 35
            )
            .fill(Color(red: 0.02, green: 0.09, blue: 0.13))
            .adaptiveFrame(width: 375, height: 785)
            .adaptiveOffset(y: 20)
            
            // Контейнер для содержимого
            VStack(spacing: 0) {
                // Верхняя область с заголовком
                VStack(spacing: 0) {
                    HStack {
                        ChevronButton {
                            nav.hideCategoriesSelection()
                        }
                        .rotationEffect(.degrees(180))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    
                    VStack(spacing: 4) {
                        Text("new bulb")
                            .font(Font.custom("DMSans-Light", size: 14))
                            .kerning(2.8)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                            .textCase(.uppercase)
                        
                        if let selectedLight = nav.selectedLight {
                            Text(selectedLight.metadata.name)
                                .font(Font.custom("DMSans-Regular", size: 12))
                                .kerning(1.8)
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                .opacity(0.8)
                                .textCase(.uppercase)
                        }
                    }
                    .padding(.top, 5)
                    
                    // Селектор типа
                    ZStack {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 332, height: 64)
                            .background(Color(red: 0.79, green: 1, blue: 1))
                            .cornerRadius(15)
                            .opacity(0.1)
                        
                        if let selectedSubtype = typeManager.getSelectedSubtype() {
                            Text("\(selectedSubtype.name)")
                                .font(Font.custom("DMSans-Light", size: 14))
                                .kerning(2.8)
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                .textCase(.uppercase)
                        } else {
                            Text("Select type")
                                .font(Font.custom("DMSans-Light", size: 14))
                                .kerning(2.8)
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                .textCase(.uppercase)
                        }
                    }
                    .padding(.top, 20)
                    
                    Text("please select bulb type")
                        .font(Font.custom("DM Sans", size: 12).weight(.light))
                        .kerning(2.4)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                        .textCase(.uppercase)
                        .padding(.top, 15)
                }
                .frame(height: 230) // Фиксированная высота для верхней части
                .adaptiveOffset(y: -10)
                // Скроллируемая область
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(typeManager.bulbTypes, id: \.id) { bulbType in
                            TupeCell(
                                bulbType: bulbType,
                                typeManager: typeManager
                            )
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Добавляем место для кнопки
                }
                .frame(maxHeight: 475) // Уменьшаем высоту для кнопки
                .clipped() // Обрезаем содержимое по границам
                
                // Кнопка сохранения
                VStack {
                    Spacer()
                    
                    if typeManager.hasSelection {
                        CostumButton(text: "save lamp", width: 250, height: 190, image: "BGCustomButton") {
                            saveLampWithCategory()
                        }
                        .padding(.bottom, 20)
                    }
                }
                .frame(height: 100)
            }
            .adaptiveFrame(width: 375, height: 785)
            .adaptiveOffset(y: 20)
        }
    }
    
    // MARK: - Обработка выбора типа лампы
    private func handleBulbTypeSelection(_ bulbType: BulbType) {
        selectedBulbType = bulbType
        print("Selected bulb type: \(bulbType.name)")
        if let selectedSubtype = typeManager.getSelectedSubtype() {
            print("Currently selected subtype: \(selectedSubtype.name)")
        } else {
            print("No subtype selected")
        }
    }
    
    // MARK: - Получение информации о выборе
    private func getSelectionInfo() -> String {
        if let selected = typeManager.getSelectedSubtype() {
            return "Selected: \(selected.name)"
        } else {
            return "No subtype selected"
        }
    }
    
    // MARK: - Сохранение лампы с категорией
    private func saveLampWithCategory() {
        guard let selectedLight = nav.selectedLight,
              let selectedSubtype = typeManager.getSelectedSubtype() else {
            print("❌ Missing selected light or subtype")
            return
        }
        
        print("💡 Сохраняем лампу: \(selectedLight.metadata.name)")
        print("📂 Выбранная категория: \(selectedSubtype.name)")
        print("🖼️ Иконка: \(selectedSubtype.iconName)")
        
        // Создаем обновленную лампу
        var updatedLight = selectedLight
        // ✅ НОВАЯ ЛОГИКА: Сохраняем пользовательский подтип отдельно от API архетипа
        updatedLight.metadata.userSubtypeName = selectedSubtype.name  // ← Название пользовательского подтипа
        updatedLight.metadata.userSubtypeIcon = selectedSubtype.iconName  // ← Иконка пользовательского подтипа
        
        // Сохраняем лампу в DataPersistenceService
        if let dataPersistenceService = nav.dataPersistenceService {
            dataPersistenceService.saveLightData(updatedLight, isAssignedToEnvironment: true)
            print("✅ Лампа сохранена: подтип='\(selectedSubtype.name)', иконка='\(selectedSubtype.iconName)'")
        }
        
        // Возвращаемся к основному экрану
        nav.resetAddBulbState()
        nav.go(.environment)
    }
}
#Preview {
    SelectCategoriesSheet()
        .environmentObject(NavigationManager.shared)
}
