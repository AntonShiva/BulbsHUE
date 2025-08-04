//
//  DismissButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct DismissButton: View {
 
        var action: () -> Void
        var body: some View {
            Button {
                action()
            } label: {
                ZStack {
                        BGCircle()
                        .adaptiveFrame(width: 47, height: 47)
                         
                         Image(systemName: "xmark")
                        .font(.system(size: 19)).fontWeight(.medium)
                             .foregroundColor(Color(red: 0.79, green: 1, blue: 1).opacity(0.9))
                     }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

#Preview {
    ZStack {
        BG()
        DismissButton{
            
        }
    }
}
