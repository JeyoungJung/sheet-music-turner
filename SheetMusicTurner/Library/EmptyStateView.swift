import SwiftUI

struct EmptyStateView: View {
    let headline: String
    let message: String
    var showImportButton: Bool = false
    var onImport: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(DesignTokens.Colors.primaryText)
                    .frame(width: 40, height: 2)
                    .padding(.bottom, DesignTokens.Spacing.md)

                Text(headline)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(DesignTokens.Colors.primaryText)
                    .padding(.bottom, DesignTokens.Spacing.sm)

                Text(message)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.secondaryText)

                if showImportButton, let onImport {
                    Button(action: onImport) {
                        Text("Import Score")
                            .font(DesignTokens.Typography.buttonBody)
                            .foregroundColor(DesignTokens.Colors.accent)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(DesignTokens.Colors.accent, lineWidth: DesignTokens.Layout.hairline)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DesignTokens.Spacing.md)
                }
            }
            .frame(maxWidth: 480, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, geometry.size.height * 0.25)
        }
    }
}
