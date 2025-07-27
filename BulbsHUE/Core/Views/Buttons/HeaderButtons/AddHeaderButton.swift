//
//  AddHeaderButton.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 27.07.2025.
//

import SwiftUI

struct AddHeaderButton: View {
    var action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                    BGCircle()
                    .adaptiveFrame(width: 47, height: 47)
                     
                     Image(systemName: "plus")
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
        
        AddHeaderButton(){
            
        }
    }
    .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2002-3&t=w7kYvAzD6FTnifyZ-4")!)
    .environment(\.figmaAccessToken, "YOUR_FIGMA_TOKEN")
}
