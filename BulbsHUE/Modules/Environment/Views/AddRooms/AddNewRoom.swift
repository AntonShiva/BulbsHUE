//
//  AddNewRoom.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

struct AddNewRoom: View {
    var body: some View {
        ZStack {
            BGLight()
            
            HeaderAddNew(title: "NEW ROOM"){
                DismissButton{
                    
                }
            }
            .adaptiveOffset(y: -323)
            
            // Список типов комнат
            
            
            CustomButtonAdaptiveRoom(text: "continue", width: 390, height: 266, image: "BGRename", offsetX: 2.3, offsetY: 18.8) {
            
            }
          
            .adaptiveOffset(y: 294)
        }
    }
}

#Preview {
    AddNewRoom()
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=39-1983&m=dev")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
