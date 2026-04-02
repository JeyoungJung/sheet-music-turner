import SwiftUI

// MARK: - Theme

/// Minimal editorial design system adapted from CreditTrackerV3.
/// Uses Inter as the primary typeface. Supports adaptive light/dark colors.
enum Theme {

    // MARK: - Typography (Inter)

    static func display() -> Font { .custom("Inter-Bold", size: 52) }
    static func light() -> Font { .custom("Inter-Light", size: 52) }
    static func thin() -> Font { .custom("Inter-Light", size: 36) }
    static func title1() -> Font { .custom("Inter-SemiBold", size: 20) }
    static func title2() -> Font { .custom("Inter-SemiBold", size: 17) }
    static func title3() -> Font { .custom("Inter-Medium", size: 15) }
    static func body() -> Font { .custom("Inter-Regular", size: 15) }
    static func caption() -> Font { .custom("Inter-Medium", size: 12) }
    static func micro() -> Font { .custom("Inter-Medium", size: 10) }
    static func number() -> Font { .custom("Inter-SemiBold", size: 13).monospacedDigit() }

    // MARK: - Colors (Adaptive)

    enum Colors {
        static let canvas = Color.adaptive(light: "#FAFAFA", dark: "#0A0A0A")
        static let surface = Color.adaptive(light: "#FFFFFF", dark: "#1A1A1A")
        static let separator = Color.adaptive(light: "#E5E5E5", dark: "#2A2A2A")

        static let textPrimary = Color.adaptive(light: "#1A1A1A", dark: "#F5F5F5")
        static let textSecondary = Color.adaptive(light: "#666666", dark: "#999999")
        static let textMuted = Color.adaptive(light: "#AAAAAA", dark: "#555555")

        static let gold = Color.adaptive(light: "#C8A55A", dark: "#D4B56A")
        static let success = Color(hex: "#34C759")
        static let warning = Color(hex: "#FFB800")
        static let danger = Color(hex: "#FF3B30")

        // Backwards-compatible aliases (used across existing codebase)
        static let primaryText = textPrimary
        static let secondaryText = textSecondary
        static let background = canvas
        static let surfaceSecondary = surface
        static let accent = gold
        static let divider = separator
    }

    // MARK: - Dimensions

    enum Dimensions {
        static let cardRadius: CGFloat = 22
        static let sheetRadius: CGFloat = 28
        static let pillRadius: CGFloat = 999
        static let cardPadding: CGFloat = 20
        static let screenPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 48
        static let innerSpacing: CGFloat = 12
        static let borderWidth: CGFloat = 1
    }

    // MARK: - Spacing (kept for existing references)

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
        static let cornerRadius: CGFloat = 22
        static let hairline: CGFloat = 1
    }

    // MARK: - Motion

    enum Motion {
        static let cardEntrance: Double = 0.5
        static let staggerDelay: Double = 0.06
        static let microInteraction: Double = 0.15
        static let pageTransition: Double = 0.4
        static let tabTransition: Double = 0.3

        static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.85)
        static let interactiveDismissSpring = Animation.spring(response: 0.38, dampingFraction: 0.82)

        static func staggeredEntrance(index: Int) -> Double {
            Double(index) * staggerDelay
        }
    }

    // MARK: - Legacy Animation aliases

    enum AnimationTokens {
        static let standard: Animation = .easeInOut(duration: Motion.microInteraction)
        static let slow: Animation = .easeInOut(duration: Motion.tabTransition)
    }
}

// MARK: - Backwards-compatible typealias

typealias DesignTokens = Theme

extension DesignTokens {
    typealias Typography = ThemeTypography
}

/// Backwards-compatible animation alias.
/// Use `Theme.AnimationTokens.standard` or `Theme.AnimationTokens.slow` directly.
enum DesignTokensAnimation {
    static let standard: SwiftUI.Animation = Theme.AnimationTokens.standard
    static let slow: SwiftUI.Animation = Theme.AnimationTokens.slow
}

/// Backwards-compatible typography that maps old names to new Theme functions
enum ThemeTypography {
    static let displayLarge: Font = Theme.display()
    static let title: Font = Theme.title1()
    static let headline: Font = Theme.title1()
    static let subheadline: Font = Theme.title2()
    static let body: Font = Theme.body()
    static let buttonBody: Font = Theme.title3()
    static let toolbarIcon: Font = Theme.title2()
    static let caption: Font = Theme.caption()
}

// MARK: - Color Utilities

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}
