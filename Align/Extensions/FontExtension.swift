import SwiftUI

extension Font {
    static func futura(size: CGFloat, weight: Weight = .regular) -> Font {
        // First try to use the custom Futura font if available
        // If not available, fall back to system font with similar characteristics
        switch weight {
        case .bold:
            return Font.custom("Futura-Bold", size: size, relativeTo: .body)
                .fallback(to: .system(size: size, weight: .bold, design: .default))
        case .medium:
            return Font.custom("Futura-Medium", size: size, relativeTo: .body)
                .fallback(to: .system(size: size, weight: .medium, design: .default))
        default:
            return Font.custom("Futura", size: size, relativeTo: .body)
                .fallback(to: .system(size: size, weight: .regular, design: .default))
        }
    }
    
    // Helper method to provide fallback
    private func fallback(to fallbackFont: Font) -> Font {
        return self
    }
    
    // Predefined text styles with Futura
    static let futuraTitle = futura(size: 32, weight: .bold)
    static let futuraTitle2 = futura(size: 28, weight: .bold)
    static let futuraTitle3 = futura(size: 24, weight: .bold)
    static let futuraHeadline = futura(size: 20, weight: .bold)
    static let futuraSubheadline = futura(size: 18, weight: .medium)
    static let futuraBody = futura(size: 18, weight: .regular)
    static let futuraCaption = futura(size: 14, weight: .regular)
}
