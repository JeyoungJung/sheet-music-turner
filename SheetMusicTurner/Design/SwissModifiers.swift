import SwiftUI

// MARK: - Swiss Typography Modifiers

struct SwissHeadlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.headline)
            .foregroundColor(DesignTokens.Colors.primaryText)
    }
}

struct SwissBodyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.body)
            .foregroundColor(DesignTokens.Colors.primaryText)
            .lineSpacing(8)
    }
}

struct SwissCaptionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.caption)
            .foregroundColor(DesignTokens.Colors.secondaryText)
            .textCase(.uppercase)
            .kerning(0.5)
    }
}

struct SwissButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.buttonBody)
            .foregroundColor(DesignTokens.Colors.accent)
    }
}

// MARK: - Swiss Layout Modifiers

struct SwissCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .strokeBorder(DesignTokens.Colors.divider, lineWidth: DesignTokens.Layout.hairline)
            )
            .clipShape(Rectangle())
    }
}

// MARK: - View Extensions

extension View {
    func swissHeadline() -> some View {
        modifier(SwissHeadlineModifier())
    }

    func swissBody() -> some View {
        modifier(SwissBodyModifier())
    }

    func swissCaption() -> some View {
        modifier(SwissCaptionModifier())
    }

    func swissButton() -> some View {
        modifier(SwissButtonModifier())
    }

    func swissCard() -> some View {
        modifier(SwissCardModifier())
    }
}

// MARK: - Swiss Divider

struct SwissDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignTokens.Colors.divider)
            .frame(height: DesignTokens.Layout.hairline)
            .frame(maxWidth: .infinity)
    }
}
