//
//  SearchResultsSheet.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 04.08.2025.
//

import SwiftUI

struct SearchResultsSheet: View {
    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 35,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 35
        )
        .fill(Color(red: 0.02, green: 0.09, blue: 0.13))
        .adaptiveFrame(width: 375, height: 342)
    }
}

#Preview {
    SearchResultsSheet()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        .compare(with: URL(string: "https://www.figma.com/design/9yYMU69BSxasCD4lBnOtet/Bulbs_HUE--Copy-?node-id=2010-2&t=N7aN39c57LpreKLv-4")!)
        .environment(\.figmaAccessToken, "figd_0tuspWW6vlV9tTm5dGXG002n2yoohRRd94dMxbXD")
}
