
import UIKit
import SwiftUI



extension UIScreen{
    static let width = UIScreen.main.bounds.size.width
    static let height = UIScreen.main.bounds.size.height
    static let size = UIScreen.main.bounds.size
    static let bouds = UIScreen.main.bounds
}

extension UIView {
    func getScreen() -> CGRect {
        guard let screen = UIApplication.shared.connectedScenes.first  as? UIWindowScene else { return .zero}
        //guard let saveArea = screen.window.first?.safeAreaInsets else { return .zero}
       
        let screenRect = screen.coordinateSpace.bounds
        
        return screenRect
    }
}

func topSaveArea() -> CGFloat {
    let top = UIApplication
        .shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.safeAreaInsets.top
    return top ?? 0
}

func bottomSaveArea() -> CGFloat {
    let top = UIApplication
        .shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.safeAreaInsets.bottom
    return top ?? 0
}

func rightSaveArea() -> CGFloat {
    let top = UIApplication
        .shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.safeAreaInsets.right
    return top ?? 0
}
