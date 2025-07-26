//
//  MusicView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 26.07.2025.
//

import SwiftUI

struct MusicView: View {
    var body: some View {
        ZStack {
            BG()
            Text("Music")
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    MusicView()
}
