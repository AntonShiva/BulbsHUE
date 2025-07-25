

import SwiftUI

public extension EnvironmentValues {

    var figmaAccessToken: String {
        get {
            self[FigmaAccessTokenKey.self]
        }
        set {
            self[FigmaAccessTokenKey.self] = newValue
        }
    }
}

struct FigmaAccessTokenKey: EnvironmentKey {

    static var defaultValue = ""
}
