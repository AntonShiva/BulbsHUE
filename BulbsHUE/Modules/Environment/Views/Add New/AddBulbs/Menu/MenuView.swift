//
//  MenuView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/13/25.
//

import SwiftUI

struct MenuView: View {
    @EnvironmentObject var nav: NavigationManager
    
    // Состояние для управления переходом между основным меню и экраном переименования
    @State private var showRenameView: Bool = false
    
    let bulbName: String
    /// Тип лампы (пользовательский подтип)
    let bulbType: String
   /// Иконка лампы
    let bulbIcon: String
    /// Базовый цвет для фона компонента
    let baseColor: Color
    
   
    init(bulbName: String,
         bulbIcon: String,
         bulbType: String,
         baseColor: Color = .purple) {
        self.bulbName = bulbName
        self.bulbIcon = bulbIcon
        self.bulbType = bulbType
        self.baseColor = baseColor
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
            .adaptiveFrame(width: 375, height: 678)
            
            DismissButton{
                nav.hideMenuView()
            }
            .adaptiveOffset(x: 130, y: -290)
            
            ZStack{
                BGItem(baseColor: baseColor)
                    .adaptiveFrame(width: 278, height: 140)
                
                Image(bulbIcon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(baseColor.preferredForeground)
                    .adaptiveFrame(width: 32, height: 32)
                    .adaptiveOffset(y: -42)
                
                Text(bulbName)
                    .font(Font.custom("DMSans-Medium", size: 20))
                    .kerning(4.2)
                    .foregroundColor(baseColor.preferredForeground)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .adaptiveOffset(y: -5)
                
                Text(bulbType)
                    .font(Font.custom("DMSans-Light", size: 14))
                    .kerning(2.8)
                    .foregroundColor(baseColor.preferredForeground.opacity(0.9))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .adaptiveOffset(y: 17)
                
                // Разделительная линия
                Rectangle()
                    .fill(baseColor.preferredForeground)
                    .adaptiveFrame(width: 212, height: 2)
                    .opacity(0.2)
                    .adaptiveOffset(y: 30)
                
                Text("no room")
                    .font(Font.custom("DMSans-Light", size: 15))
                    .kerning(3)
                    .foregroundColor(baseColor.preferredForeground.opacity(0.9))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .adaptiveOffset(y: 48.5)
            }
            .adaptiveOffset(y: -173)
            
            
            if !showRenameView {
                VStack(spacing: 9.5) {
                    // Кнопка "Change type"
                    Button {
                       
                    } label: {
                        HStack(spacing: 43) {
                            Image(bulbIcon)
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: 40, height: 40)
                            
                            Text("Change type")
                                .font(Font.custom("InstrumentSans-Medium", size: 20))
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .adaptiveFrame(height: 60)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Разделитель
                    Rectangle()
                        .fill(baseColor.preferredForeground)
                        .adaptiveFrame(height: 2)
                        .opacity(0.2)
                        
                    
                    // Кнопка "Rename"
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showRenameView = true
                        }
                       
                    } label: {
                        HStack(spacing: 43) {
                            Image("Rename")
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: 40, height: 40)
                            
                            Text("Rename")
                                .font(Font.custom("InstrumentSans-Medium", size: 20))
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .adaptiveFrame(height: 60)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Разделитель
                    Rectangle()
                        .fill(baseColor.preferredForeground)
                        .adaptiveFrame(height: 2)
                        .opacity(0.2)
                       
                    
                    // Кнопка "Reorganize"
                    Button {
                       
                    } label: {
                        HStack(spacing: 43) {
                            Image("Reorganize")
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: 40, height: 40)
                            
                            Text("Reorganize")
                                .font(Font.custom("InstrumentSans-Medium", size: 20))
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .adaptiveFrame(height: 60)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Разделитель
                    Rectangle()
                        .fill(baseColor.preferredForeground)
                        .adaptiveFrame(height: 2)
                        .opacity(0.2)
                      
                    
                    // Кнопка "Delete Bulb"
                    Button {
                        
                    } label: {
                        HStack(spacing: 43) {
                            Image("Delete")
                                .resizable()
                                .scaledToFit()
                                .adaptiveFrame(width: 40, height: 40)
                            
                            Text("Delete Bulb")
                                .font(Font.custom("InstrumentSans-Medium", size: 20))
                                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .adaptiveFrame(height: 60)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
            .adaptiveFrame(width: 292, height: 280)
            .adaptiveOffset(y: 106)
            } else {
                ZStack {
                    Text("your new bulb name")
                        .font(Font.custom("DMSans-Regular", size: 14))
                        .kerning(2.8)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    .adaptiveOffset(y: -20)
                    
                    ZStack{
                    Rectangle()
                        .foregroundColor(.clear)
                        .adaptiveFrame(width: 332, height: 64)
                        .background(Color(red: 0.79, green: 1, blue: 1))
                        .cornerRadius(15)
                        .opacity(0.1)
                       
                    
                    Text("bulb name")
                        .font(Font.custom("DMSans-Regular", size: 14))
                        .kerning(2.8)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                }
                      .adaptiveOffset(y: 34)
                    
                    CustomButtonAdaptive(text: "rename", width: 390, height: 266, image: "BGRename", offsetX: 0, offsetY: 17)  {
                        // TODO: Реализовать сохранение нового имени лампы
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showRenameView = false
                        }
                        print("💾 Save rename pressed")
                    }
                    .adaptiveOffset(y: 211)
                   
                }
                .textCase(.uppercase)
            }
            
            
        }
        .adaptiveOffset(y: 67)
    }
}
#Preview {
    MenuView(bulbName: "Ламочка ул", bulbIcon: "f2", bulbType: "Лщджия")
        .environmentObject(NavigationManager.shared)
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=120-879&t=aTBbxHC3igKeQH3e-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
       
}
#Preview {
    MenuView(bulbName: "bulb name", bulbIcon: "t1", bulbType: "Лщджия")
        .environmentObject(NavigationManager.shared)
}



