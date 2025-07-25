import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Структура для хранения базовых размеров
struct AdaptiveLayoutConstants {
    static let baseWidth: CGFloat = 375
    static let baseHeight: CGFloat = 812
}
// Вспомогательный класс для расчета адаптивных размеров
struct AdaptiveLayoutCalculator {
    // Адаптивная ширина - пропорциональна ширине устройства
    static func adaptiveWidth(_ width: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width * (width / AdaptiveLayoutConstants.baseWidth)
        #else
        // Резервный вариант для платформ без UIKit
        return width
        #endif
    }
    
    // Адаптивная высота - пропорциональна высоте устройства
    static func adaptiveHeight(_ height: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.height * (height / AdaptiveLayoutConstants.baseHeight)
        #else
        // Резервный вариант для платформ без UIKit
        return height
        #endif
    }
} 

// Модификатор для адаптивных рамок
struct AdaptiveFrame: ViewModifier {
    let width: CGFloat?
    let height: CGFloat?
    
    func body(content: Content) -> some View {
        content.frame(
            width: width != nil ? AdaptiveLayoutCalculator.adaptiveWidth(width!) : nil,
            height: height != nil ? AdaptiveLayoutCalculator.adaptiveHeight(height!) : nil
        )
    }
}

// Расширение для адаптивного интерфейса
extension View {
    // Удобный модификатор для задания адаптивных рамок
    func adaptiveFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self.modifier(AdaptiveFrame(width: width, height: height))
    }
    
    // Удобный модификатор для адаптивных отступов
    func adaptivePadding(
        top: CGFloat? = nil,
        leading: CGFloat? = nil,
        bottom: CGFloat? = nil,
        trailing: CGFloat? = nil,
        horizontal: CGFloat? = nil,
        vertical: CGFloat? = nil
    ) -> some View {
        let adaptedTop = top != nil ? AdaptiveLayoutCalculator.adaptiveHeight(top!) : (vertical != nil ? AdaptiveLayoutCalculator.adaptiveHeight(vertical!) : 0)
        let adaptedLeading = leading != nil ? AdaptiveLayoutCalculator.adaptiveWidth(leading!) : (horizontal != nil ? AdaptiveLayoutCalculator.adaptiveWidth(horizontal!) : 0)
        let adaptedBottom = bottom != nil ? AdaptiveLayoutCalculator.adaptiveHeight(bottom!) : (vertical != nil ? AdaptiveLayoutCalculator.adaptiveHeight(vertical!) : 0)
        let adaptedTrailing = trailing != nil ? AdaptiveLayoutCalculator.adaptiveWidth(trailing!) : (horizontal != nil ? AdaptiveLayoutCalculator.adaptiveWidth(horizontal!) : 0)
        
        return self.padding(
            EdgeInsets(
                top: adaptedTop,
                leading: adaptedLeading,
                bottom: adaptedBottom,
                trailing: adaptedTrailing
            )
        )
    }
    
    // Более простой вариант adaptivePadding для всех сторон или конкретного набора
    func adaptivePadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        if let length = length {
            let adaptedLength = edges.contains(.top) || edges.contains(.bottom) ? 
                AdaptiveLayoutCalculator.adaptiveHeight(length) : 
                AdaptiveLayoutCalculator.adaptiveWidth(length)
            return padding(edges, adaptedLength)
        } else {
            return padding()
        }
    }
    
    // Удобный модификатор для адаптивных смещений
    func adaptiveOffset(x: CGFloat? = nil, y: CGFloat? = nil) -> some View {
        let adaptedX = x != nil ? AdaptiveLayoutCalculator.adaptiveWidth(x!) : nil
        let adaptedY = y != nil ? AdaptiveLayoutCalculator.adaptiveHeight(y!) : nil
        return offset(x: adaptedX ?? 0, y: adaptedY ?? 0)
    }
    
    // Комбинированное смещение (удобно для передачи из фигмы)
    func adaptiveOffset(_ offset: CGPoint) -> some View {
        let adaptedX = AdaptiveLayoutCalculator.adaptiveWidth(offset.x)
        let adaptedY = AdaptiveLayoutCalculator.adaptiveHeight(offset.y)
        return self.offset(x: adaptedX, y: adaptedY)
    }
    
    func adaptiveHeight(_ height: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.height * (height / AdaptiveLayoutConstants.baseHeight)
        #else
        // Резервный вариант для платформ без UIKit
        return height
        #endif
    }
    func adaptiveWidth(_ width: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width * (width / AdaptiveLayoutConstants.baseWidth)
        #else
        // Резервный вариант для платформ без UIKit
        return width
        #endif
    }
}
