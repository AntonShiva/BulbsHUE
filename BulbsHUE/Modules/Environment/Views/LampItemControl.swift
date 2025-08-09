//
//  LampItemControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/9/25.
//

import SwiftUI

struct LampItemControl: View {
    @Binding var percent: Double
    var body: some View {
        ZStack {
            lampControlView()
                .adaptiveOffset(x: -36)
            
            CustomSlider(percent: $percent,
                         color: Color(red: 0.55, green: 0.24, blue: 0.67))
            .adaptiveOffset(x: 143)
        }
    }
}

#Preview {
    LampItemControl(percent: .constant(10.5))
}
