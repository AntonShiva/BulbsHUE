//
//  SelectСategoriesSheet.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 05.08.2025.
//

import SwiftUI
// Model
struct BulbType {
    let id = UUID()
    let name: String
    let iconName: String
    let iconWidth: CGFloat
    let iconHeight: CGFloat
}

struct SelectCategoriesSheet: View {
    @State private var selectedBulbType: BulbType?
    // Данные типов ламп
     private let bulbTypes: [BulbType] = [
         BulbType(name: "TABLE", iconName: "table", iconWidth: 24, iconHeight: 24),
         BulbType(name: "FLOOR", iconName: "floor", iconWidth: 24, iconHeight: 24),
         BulbType(name: "CEILING", iconName: "ceiling", iconWidth: 24, iconHeight: 20),
         BulbType(name: "WALL", iconName: "wall", iconWidth: 24, iconHeight: 24),
         BulbType(name: "OTHER", iconName: "other", iconWidth: 24, iconHeight: 24)
     ]
    var body: some View {
             ZStack{
                UnevenRoundedRectangle(
                    topLeadingRadius: 35,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 35
                )
                .fill(Color(red: 0.02, green: 0.09, blue: 0.13))
                .adaptiveFrame(width: 375, height: 785)
                .adaptiveOffset(y: 20)
                
                SelectCategoryButton{
                    
                }
                .rotationEffect(.degrees(180))
                .adaptiveOffset(x: -140, y: -325)
                
                Text("new bulb")
                  .font( Font.custom("DMSans-Light", size: 14))
                  .kerning(2.8)
                  .multilineTextAlignment(.center)
                  .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                  .textCase(.uppercase)
                  .adaptiveOffset( y: -325)
                
                                ZStack {
                                    Rectangle()
                                        .foregroundColor(.clear)
                                        .frame(width: 332, height: 64)
                                        .background(Color(red: 0.79, green: 1, blue: 1))
                                        .cornerRadius(15)
                                        .opacity(0.1)
                
                
                                    Text("Select type")
                                      .font( Font.custom("DMSans-Light", size: 14))
                                      .kerning(2.8)
                                      .multilineTextAlignment(.center)
                                      .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                                      .textCase(.uppercase)
                                }
                                .adaptiveOffset( y: -250)
                
                Text("please select bulb type")
                  .font(
                    Font.custom("DM Sans", size: 12)
                      .weight(.light)
                  )
                  .kerning(2.4)
                  .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                  .textCase(.uppercase)
                  .adaptiveOffset( y: -180)
                
                ScrollView {
                
                    VStack(spacing: 8) {
                        ForEach(bulbTypes, id: \.id) { bulbType in
                            TupeCell(
                                text: bulbType.name,
                                image: bulbType.iconName,
                                width: bulbType.iconWidth,
                                height: bulbType.iconHeight
                                )
                             {
                                // Обработка нажатия
                                 
                                selectedBulbType = bulbType
                                handleBulbTypeSelection(bulbType)
                            }
                        }
                    }
                    .adaptiveOffset( y: 250)
                
            }
        }
    }
    
    // MARK: - Обработка выбора типа лампы
        private func handleBulbTypeSelection(_ bulbType: BulbType) {
            // Здесь нжно добавить навигацию
            
        }
}

#Preview {
    SelectCategoriesSheet()
}


// MARK: - Тестовая сцена
struct ExpandableCellTestView: View {
    @State private var selectedSubtypes: Set<UUID> = []
    
    private let tableSubtypes = [
        LampSubtype(name: "Traditional Lamp", iconName: "t1", isSelected: true),
        LampSubtype(name: "Desk Lamp", iconName: "t2", isSelected: false),
        LampSubtype(name: "Table Wash", iconName: "t3", isSelected: false)
    ]
    
    private let floorSubtypes = [
        LampSubtype(name: "Floor Type 1", iconName: "f1", isSelected: false),
        LampSubtype(name: "Floor Type 2", iconName: "f2", isSelected: false),
        LampSubtype(name: "Floor Type 3", iconName: "f3", isSelected: false),
        LampSubtype(name: "Floor Type 4", iconName: "f4", isSelected: false)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Ячейка TABLE с расширением и поворотом кнопки
                TupeCell(
                    text: "TABLE",
                    image: "table",
                    width: 24,
                    height: 24,
                    cellHeight: 64,
                    subtypes: tableSubtypes,
                       //  Расширять ячейку
                    onTap: {
                        print("TABLE tapped")
                    },
                    onSubtypeSelect: { subtype in
                        print("Selected: \(subtype.name)")
                    }
                )
                
               

                
                // Ячейка FLOOR с расширением и поворотом кнопки
                TupeCell(
                    text: "FLOOR",
                    image: "floor",
                    width: 24,
                    height: 24,
                    cellHeight: 64,
                    subtypes: floorSubtypes,
                      // Расширять ячейку
                    onTap: {
                        print("FLOOR tapped")
                    },
                    onSubtypeSelect: { subtype in
                        print("Selected: \(subtype.name)")
                    }
                )
                
                // Обычная ячейка без расширения и поворота
                TupeCell(
                    text: "CEILING",
                    image: "ceiling",
                    width: 24,
                    height: 24,
                    cellHeight: 64,
                    subtypes: [],
                     // НЕ расширять ячейку
                    onTap: {
                        print("CEILING tapped")
                    }
                )
            }
            .padding()
        }
        .background(Color(red: 0.15, green: 0.2, blue: 0.25))
    }
}



// MARK: - Preview
struct ExpandableCellTestView_Previews: PreviewProvider {
    static var previews: some View {
        ExpandableCellTestView()
    }
}
