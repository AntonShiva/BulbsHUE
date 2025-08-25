//
//  RoomManagementCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/25/25.
//

import SwiftUI

struct RoomManagementCell: View{
    var iconName: String
    var roomName: String
    var roomType: String
    
    var body: some View {
        ZStack(alignment: .top) {
            // Расширяемый фон
            Rectangle()
                .foregroundColor(.clear)
                .adaptiveFrame(width: 332, height: 64)
                .background(Color(red: 0.79, green: 1, blue: 1))
                .cornerRadius(15)
                .opacity(0.1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            
            VStack(spacing: 0) {
                // Основная ячейка (неизменная часть)
                ZStack {
                    HStack {
                        HStack(spacing: 0) {
                            // Иконка типа - используем настраиваемые или стандартные размеры
                            Image(iconName)
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: 32, height: 32)
                                .adaptiveFrame(width: 72) // Фиксированная область для иконки
                            VStack(spacing: 2){
                                // Название типа - берется из typeData
                                Text(roomName)
                                    .font(Font.custom("DMSans-Regular", size: 14))
                                    .kerning(3)
                                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                   
                                
                                Text(roomType)
                                  .font(Font.custom("DM Sans", size: 12))
                                  .kerning(2.4)
                                  .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                  .opacity(0.4)
                                  .frame(maxWidth: .infinity, alignment: .leading)
                                
                            }
                            .textCase(.uppercase)
                            .adaptiveOffset(x: 6)
                            // Кнопка с поворотом - поворачивается только если есть подтипы
                            ChevronButton{
                               
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                       
                                }
                            }
                           
                            .adaptiveFrame(width: 60)
                        }
                        .adaptivePadding(.trailing, 10)
                    }
                    .adaptiveFrame(width: 332, height: 64)
                }
                
            
            }
        }
    }
}

#Preview {
    ZStack{
        BG()
        
        RoomManagementCell(iconName: "tr1", roomName: "Room name", roomType: "room type")
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2075-219&t=sC3aD0A4Ffr835aT-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}

