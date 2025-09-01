//
//  IntensitySettingView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 9/1/25.
//

import SwiftUI


    enum IntensityType: String, CaseIterable {
        case low = "low"
        case middle = "middle"
        case hight = "high"
        
        var displayName: String {
            switch self {
            case .low:
                return String(localized: "LOW")
            case .middle:
                return String(localized: "MIDDLE")
            case .hight:
                return String(localized: "HIGHT")
            }
        }
    }



    // Версия с биндингом для использования в родительских View
struct IntensitySettingView: View {
        @Binding var intensityType: IntensityType
        @State private var isExpanded: Bool = false
        
        var body: some View {
            // Основная ячейка (фиксированный размер)
            ZStack {
                Rectangle()
                    .foregroundColor(.clear)
                    .adaptiveFrame(width: 332, height: 64)
                    .background(Color(red: 0.99, green: 0.98, blue: 0.84))
                    .cornerRadius(12)
                    .opacity(isExpanded ? 0 : 0.1)
                
                ZStack {
                    // Icon placeholder
                  Image("intensity")
                        .resizable()
                        .scaledToFit()
                    .adaptiveFrame(width: 32, height: 32)
                    .adaptiveOffset(x: -134)
                    .opacity(isExpanded ? 0 : 1)
                    
                    // Title
                    Text(String(localized: "INTENSITY"))
                        .font(Font.custom("DMSans-Regular", size: 14.3))
                        .tracking(2.80)
                        .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                        .adaptiveOffset(x: isExpanded ? 0 : -50 )
                   
                    
                    // Current value
                    Text(intensityType.displayName)
                        .font(Font.custom("DMSans-Black", size: 14))
                        .tracking(2.80)
                        .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                        .opacity(isExpanded ? 0 : 1)
                        .adaptiveOffset(x: 102)
                }
               
            }
            .adaptiveFrame(width: 332, height: 64)
            
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
            .overlay(alignment: .bottom) {
                // Расширенные опции появляются как overlay снизу
                if isExpanded {
                    ZStack {
                        Rectangle()
                            .foregroundColor(.clear)
                            .adaptiveFrame(width: 332, height: 64)
                            .background(Color(red: 0.99, green: 0.98, blue: 0.84))
                            .cornerRadius(12)
                            .opacity(0.1)
                        
                        HStack(spacing: 0) {
                            // Classic option
                            Button(action: {
                                intensityType = .low
    //                            withAnimation(.easeInOut(duration: 0.3)) {
    //                                isExpanded = false
    //                            }
                            }) {
                                ZStack {
                                   UnevenRoundedRectangle(
                                        topLeadingRadius: 12,
                                        bottomLeadingRadius: 12,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 0
                                    )
                                    .fill(Color(red: 0.99, green: 0.98, blue: 0.84))
                                  .adaptiveFrame(width: 112, height: 64)
                                  .opacity(intensityType == .low ? 0.1 : 0)
                                
                                   
                                    
                                    Text(IntensityType.low.displayName)
                                        .font(Font.custom("DM Sans", size: 14).weight(intensityType == .low ? .black : .medium))
                                        .tracking(2.80)
                                        .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                                        
                                }
                            }
                            
                            
                          
                            Button(action: {
                                intensityType = .middle
    //                            withAnimation(.easeInOut(duration: 0.3)) {
    //                                isExpanded = false
    //                            }
                            }) {
                                ZStack {
                                    UnevenRoundedRectangle(
                                         topLeadingRadius: 0,
                                         bottomLeadingRadius: 0,
                                         bottomTrailingRadius: 0,
                                         topTrailingRadius: 0
                                     )
                                     .fill(Color(red: 0.99, green: 0.98, blue: 0.84))
                                   .adaptiveFrame(width: 112, height: 64)
                                   .opacity(intensityType == .middle ? 0.1 : 0)
                                    
                                    Text(IntensityType.middle.displayName)
                                        .font(Font.custom("DM Sans", size: 14).weight(intensityType == .middle ? .black : .medium))
                                        .tracking(2.80)
                                        .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            Button(action: {
                                intensityType = .hight
    //                            withAnimation(.easeInOut(duration: 0.3)) {
    //                                isExpanded = false
    //                            }
                            }) {
                                ZStack {
                                    UnevenRoundedRectangle(
                                         topLeadingRadius: 0,
                                         bottomLeadingRadius: 0,
                                         bottomTrailingRadius: 12,
                                         topTrailingRadius: 12
                                     )
                                     .fill(Color(red: 0.99, green: 0.98, blue: 0.84))
                                   .adaptiveFrame(width: 112, height: 64)
                                   .opacity(intensityType == .hight ? 0.1 : 0)
                                    
                                    Text(IntensityType.hight.displayName)
                                        .font(Font.custom("DM Sans", size: 14).weight(intensityType == .hight ? .black : .medium))
                                        .tracking(2.80)
                                        .foregroundColor(Color(red: 0.99, green: 0.98, blue: 0.84))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                    }
                    .offset(y: 64) // Сдвигаем на высоту основной ячейки
                    .scaleEffect(x: 1, y: isExpanded ? 1 : 0, anchor: .top)
                    .opacity(isExpanded ? 1 : 0)
                    .zIndex(1) // Поверх других элементов
                }
            }
            .zIndex(isExpanded ? 10 : 1) // Весь компонент поверх других при расширении
        }
    }

#Preview {
    ZStack {
        BG()
        
        // Пример с биндингом
        IntensitySettingView(intensityType: .constant(.middle))
        
        
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2242-9&t=gFp2PiVIXvPVfHoZ-4")!)
    .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
