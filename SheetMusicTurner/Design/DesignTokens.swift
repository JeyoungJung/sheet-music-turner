import SwiftUI

enum DesignTokens {

    // MARK: - Typography
    enum Typography {
        static let displayLarge: Font = .system(size: 64, weight: .black, design: .default)
        static let title: Font = .system(size: 44, weight: .bold, design: .default)
        static let headline: Font = .system(size: 32, weight: .bold, design: .default)
        static let subheadline: Font = .system(size: 18, weight: .medium, design: .default)
        static let body: Font = .system(size: 16, weight: .regular, design: .default)
        static let buttonBody: Font = .system(size: 16, weight: .medium, design: .default)
        static let toolbarIcon: Font = .system(size: 18, weight: .medium, design: .default)
        static let caption: Font = .system(size: 11, weight: .bold, design: .default)
    }

    // MARK: - Colors
    enum Colors {
        static let primaryText = Color("PrimaryText")
        static let secondaryText = Color("SecondaryText")
        static let background = Color("Background")
        static let surfaceSecondary = Color("SurfaceSecondary")
        static let accent = Color("Accent")
        static let divider = Color("Divider")
    }

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 16
        static let md: CGFloat = 24
        static let lg: CGFloat = 32
        static let xl: CGFloat = 48
        static let xxl: CGFloat = 64
        static let xxxl: CGFloat = 96
        static let listRow: CGFloat = 12
    }

    // MARK: - Layout
    enum Layout {
        static let marginCompact: CGFloat = 40
        static let marginRegular: CGFloat = 60
        static let gutter: CGFloat = 20
        static let cornerRadius: CGFloat = 0
        static let hairline: CGFloat = 1
    }

    // MARK: - Animation
    enum Animation {
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.2)
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.3)
    }
}