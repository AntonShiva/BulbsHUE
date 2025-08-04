//
//  SelectCategoryButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct SelectCategoryButton: View {
    var action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                    BGCircle()
                    .adaptiveFrame(width: 47, height: 47)
                     
                     Image(systemName: "chevron.right")
                    .font(.system(size: 16)).fontWeight(.bold)
                         .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.9))
                 }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        BG()
        SelectCategoryButton{
            
        }
    }
}
