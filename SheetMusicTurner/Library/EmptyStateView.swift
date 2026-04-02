import SwiftUI

struct EmptyStateView: View {
    let headline: String
    let message: String
    var showImportButton: Bool = false
    var onImport: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.Colors.gold)
                    .frame(width: 40, height: 3)
                    .padding(.bottom, Theme.Spacing.md)

                Text(headline)
                    .font(Theme.title1())
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, Theme.Spacing.sm)

                Text(message)
                    .font(Theme.body())
                    .foregroundColor(Theme.Colors.textSecondary)

                if showImportButton, let onImport {
                    Button(action: onImport) {
                        Text("Import Score")
                            .font(Theme.title3())
                            .foregroundColor(.white)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs + 4)
                            .background(Theme.Colors.gold)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.Spacing.md)
                }
            }
            .padding(Theme.Dimensions.cardPadding)
            .frame(maxWidth: 480, alignment: .leading)
            .minimalCard()
            .padding(.horizontal, Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, geometry.size.height * 0.25)
        }
    }
}
