import SwiftUI

// MARK: - MinimalCard Component

/// A rounded card container following the CreditTrackerV3 editorial design system.
/// Surface background, 22pt corner radius, optional subtle separator border.
struct MinimalCard<Content: View>: View {
    let showBorder: Bool
    let content: Content

    init(showBorder: Bool = true, @ViewBuilder content: () -> Content) {
        self.showBorder = showBorder
        self.content = content()
    }

    var body: some View {
        content
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.separator, lineWidth: showBorder ? Theme.Dimensions.borderWidth : 0)
            )
    }
}

// MARK: - Typography Modifiers

struct SwissHeadlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.title1())
            .foregroundColor(Theme.Colors.textPrimary)
    }
}

struct SwissBodyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.body())
            .foregroundColor(Theme.Colors.textPrimary)
            .lineSpacing(4)
    }
}

struct SwissCaptionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.caption())
            .foregroundColor(Theme.Colors.textSecondary)
            .textCase(.uppercase)
            .kerning(0.3)
    }
}

struct SwissButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.title3())
            .foregroundColor(Theme.Colors.gold)
    }
}

// MARK: - Card Modifier

struct SwissCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.separator, lineWidth: Theme.Dimensions.borderWidth)
            )
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

    /// Convenience for wrapping content in a MinimalCard.
    func minimalCard(showBorder: Bool = true) -> some View {
        MinimalCard(showBorder: showBorder) {
            self
        }
    }
}

// MARK: - Divider

struct SwissDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(Theme.Colors.separator)
            .frame(height: Theme.Layout.hairline)
            .frame(maxWidth: .infinity)
    }
}
