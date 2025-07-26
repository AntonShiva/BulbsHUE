//
//  EnvironmentView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct EnvironmentView: View {
    var body: some View {
        ZStack {
            BG()
            Text("Envirement")
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    EnvironmentView()
}
