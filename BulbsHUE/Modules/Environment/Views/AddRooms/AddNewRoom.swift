//
//  AddNewRoom.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

struct AddNewRoom: View {
    @StateObject private var categoryManager = RoomCategoryManager()
    @EnvironmentObject var nav: NavigationManager
    
    var body: some View {
        ZStack {
            BGLight()
            
            HeaderAddNew(title: "NEW ROOM"){
                DismissButton{
                    nav.go(.environment)
                }
            }
            .adaptiveOffset(y: -323)
            
            VStack(spacing: 0) {
                // Заголовок
                VStack(spacing: 20) {
                    Text("NEW ROOM")
                        .font(Font.custom("DMSans-Bold", size: 20))
                        .kerning(3.6)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                        .textCase(.uppercase)
                    
                    Text("please select room type")
                        .font(Font.custom("DM Sans", size: 12).weight(.light))
                        .kerning(2.4)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                        .textCase(.uppercase)
                }
                .frame(height: 100)
                .adaptiveOffset(y: -100)
                
                // Скроллируемая область с категориями комнат
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(categoryManager.roomCategories, id: \.id) { roomCategory in
                            RoomTupeCell(
                                roomCategory: roomCategory,
                                categoryManager: categoryManager
                            )
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Добавляем место для кнопки
                }
                
                
                // Кнопка продолжения
                VStack {
                    Spacer()
                    
                    if categoryManager.hasSelection {
                        CustomButtonAdaptiveRoom(text: "continue", width: 390, height: 266, image: "BGRename", offsetX: 2.3, offsetY: 18.8) {
                            saveRoomWithType()
                        }
                        .padding(.bottom, 20)
                    }
                }
                .frame(height: 100)
            }
            .adaptiveFrame(width: 375, height: 785)
        }
    }
    
    // MARK: - Сохранение комнаты с типом
    private func saveRoomWithType() {
        guard let selectedSubtype = categoryManager.getSelectedSubtype() else {
            print("❌ Missing selected room subtype")
            return
        }
        
        // Здесь будет логика создания комнаты
        print("✅ Комната будет создана: тип='\(selectedSubtype.name)', иконка='\(selectedSubtype.iconName)'")
        
        // Возвращаемся к основному экрану
        nav.go(.environment)
    }
}

#Preview {
    AddNewRoom()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=39-1983&m=dev")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
