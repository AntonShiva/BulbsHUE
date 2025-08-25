//
//  ReorganizeRoomCell.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/22/25.
//

import SwiftUI

struct ReorganizeRoomCell: View {
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
            
            VStack(spacing: 8) {
                // Основная ячейка (неизменная часть)
                ZStack {
                    HStack {
                        HStack(spacing: 0) {
                            // Иконка типа
                            Image("lightBulb")
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: 32, height: 32)
                                .adaptiveFrame(width: 66)
                            
                            // Название типа - берется из typeData
                            VStack {
                                Text("Bulb name")
                                    .font(Font.custom("DMSans-Regular", size: 14))
                                    .kerning(3)
                                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                
                                Text("room name")
                                    .font(Font.custom("DM Sans", size: 12))
                                    .kerning(2.4)
                                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                    .opacity(0.4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .textCase(.uppercase)
                            .adaptiveOffset(x: 6)
                            
                        }
                        .adaptivePadding(.trailing, 10)
                        
                        HStack{
                            Button {
                                
                            } label: {
                                Image("Delete")
                                    .resizable()
                                    .scaledToFit()
                                    .adaptiveFrame(width: 24, height: 24)
                            }
                            .adaptiveFrame(width: 52)
                            .buttonStyle(.plain)
                            
                            Rectangle()
                                .fill(Color(red: 0.79, green: 1, blue: 1))
                                .adaptiveFrame(width: 1.5, height: 40)
                                .opacity(0.2)
                            
                            Button {
                                
                            } label: {
                                Image("ReorganizeRoom")
                                    .resizable()
                                    .scaledToFit()
                                    .adaptiveFrame(width: 22, height: 22)
                                    .adaptiveFrame(width: 52)
                            }
                            .buttonStyle(.plain)
                        }
                        .adaptiveFrame(width: 30)
                        
                        .adaptiveOffset(x: -50)
                        
                    }
                    
                }
                .adaptiveFrame(width: 332, height: 64)
                if true{
                // list of rooms
                VStack{
                    ZStack{
                        Rectangle()
                            .foregroundColor(.clear)
                            .adaptiveFrame(width: 332, height: 264)
                            .background(Color(red: 0.79, green: 1, blue: 1).opacity(0.1))
                            .cornerRadius(15)
                            .blur(radius: 2)
                        VStack(spacing: 15){
                            HStack{
                                Image("ReorganizeRoom")
                                    .resizable()
                                    .scaledToFit()
                                    .adaptiveFrame(width: 22, height: 22)
                                    .adaptivePadding(.trailing, 8)
                                
                                Text("move bulb to")
                                    .font( Font.custom("DMSans-Light", size: 16))
                                    .kerning(2.72)
                                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                    .textCase(.uppercase)
                            }
                            
                            
                            // список комнат
                            VStack{
                                RoomManagementCell(iconName: "tr1", roomName: "Room name", roomType: "room type")
                                RoomManagementCell(iconName: "tr1", roomName: "Room name", roomType: "room type")
                                RoomManagementCell(iconName: "tr1", roomName: "Room name", roomType: "room type")
                                
                            }
                        }
                    }
                }
            }
            }
        }
    }
}

#Preview {
    ZStack{
        BG()
        ReorganizeRoomCell()
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2075-219&t=p1MiOXAQpotRB4uj-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
