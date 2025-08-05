//
//  SelectСategoriesSheet.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 05.08.2025.
//

import SwiftUI

struct SelectCategoriesSheet: View {
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
                            
                        }
                        .rotationEffect(.degrees(180))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    
                    Text("new bulb")
                        .font(Font.custom("DMSans-Light", size: 14))
                        .kerning(2.8)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                        .textCase(.uppercase)
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
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: 575) // Ограничиваем высоту скролла
                .clipped() // Обрезаем содержимое по границам
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
}
#Preview {
    SelectCategoriesSheet()
}
