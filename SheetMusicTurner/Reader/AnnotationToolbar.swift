import SwiftUI

#if canImport(UIKit)
import UIKit
typealias AnnotationColorValue = UIColor
#elseif canImport(AppKit)
import AppKit
typealias AnnotationColorValue = NSColor
#endif

enum AnnotationTool: String, CaseIterable {
    case pen
    case eraser
    case instantEraser
    case lasso

    var symbolName: String {
        switch self {
        case .pen:
            return "pencil.tip"
        case .eraser:
            return "eraser"
        case .instantEraser:
            return "eraser.line.dashed"
        case .lasso:
            return "lasso"
        }
    }
}

enum AnnotationToolbarColor: String, CaseIterable, Identifiable {
    case black
    case red
    case blue
    case green
    case orange

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .black:
            return .black
        case .red:
            return Color(red: 1.0, green: 59.0 / 255.0, blue: 48.0 / 255.0)
        case .blue:
            return Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0)
        case .green:
            return Color(red: 52.0 / 255.0, green: 199.0 / 255.0, blue: 89.0 / 255.0)
        case .orange:
            return Color(red: 1.0, green: 149.0 / 255.0, blue: 0.0)
        }
    }

    var colorValue: AnnotationColorValue {
        switch self {
        case .black:
            return .black
        case .red:
            return AnnotationColorValue(red: 1.0, green: 59.0 / 255.0, blue: 48.0 / 255.0, alpha: 1.0)
        case .blue:
            return AnnotationColorValue(red: 0.0, green: 122.0 / 255.0, blue: 1.0, alpha: 1.0)
        case .green:
            return AnnotationColorValue(red: 52.0 / 255.0, green: 199.0 / 255.0, blue: 89.0 / 255.0, alpha: 1.0)
        case .orange:
            return AnnotationColorValue(red: 1.0, green: 149.0 / 255.0, blue: 0.0, alpha: 1.0)
        }
    }
}

struct AnnotationToolbar: View {
    static let height: CGFloat = 72

    @Binding var activeTool: AnnotationTool
    @Binding var activeColor: AnnotationToolbarColor
    @Binding var activeThickness: CGFloat

    let onToolChanged: (AnnotationTool) -> Void
    let onColorChanged: (AnnotationColorValue) -> Void
    let onThicknessChanged: (CGFloat) -> Void

    private let thicknessOptions: [CGFloat] = [1, 3, 6]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Spacer(minLength: 0)
            toolSection
            sectionDivider
            colorSection
            sectionDivider
            thicknessSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(DesignTokens.Colors.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Colors.divider)
                .frame(height: 0.5)
        }
        .animation(DesignTokens.Animation.standard, value: activeTool)
        .animation(DesignTokens.Animation.standard, value: activeColor.rawValue)
        .animation(DesignTokens.Animation.standard, value: activeThickness)
    }

    private var toolSection: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(AnnotationTool.allCases, id: \.rawValue) { tool in
                Button {
                    withAnimation(DesignTokens.Animation.standard) {
                        activeTool = tool
                    }
                    onToolChanged(tool)
                } label: {
                    toolbarButton(isActive: activeTool == tool) {
                        Image(systemName: tool.symbolName)
                            .font(DesignTokens.Typography.toolbarIcon)
                            .foregroundStyle(activeTool == tool ? DesignTokens.Colors.primaryText : DesignTokens.Colors.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colorSection: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(AnnotationToolbarColor.allCases) { color in
                Button {
                    withAnimation(DesignTokens.Animation.standard) {
                        activeColor = color
                    }
                    onColorChanged(color.colorValue)
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 24, height: 24)

                        if activeColor == color {
                            Circle()
                                .stroke(DesignTokens.Colors.background, lineWidth: 1.5)
                                .frame(width: 19, height: 19)

                            Circle()
                                .stroke(DesignTokens.Colors.accent, lineWidth: 2)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var thicknessSection: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(thicknessOptions, id: \.self) { thickness in
                Button {
                    withAnimation(DesignTokens.Animation.standard) {
                        activeThickness = thickness
                    }
                    onThicknessChanged(thickness)
                } label: {
                    toolbarButton(isActive: activeThickness == thickness) {
                        Text(symbol(for: thickness))
                            .font(DesignTokens.Typography.toolbarIcon)
                            .foregroundStyle(activeThickness == thickness ? DesignTokens.Colors.primaryText : DesignTokens.Colors.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.divider)
            .frame(width: 0.5, height: 24)
    }

    private func toolbarButton<Content: View>(isActive: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
            Rectangle()
                .fill(DesignTokens.Colors.accent)
                .frame(width: 20, height: 2)
                .opacity(isActive ? 1 : 0)
        }
        .frame(width: 40, height: 44)
        .contentShape(Rectangle())
    }

    private func symbol(for thickness: CGFloat) -> String {
        switch thickness {
        case 1:
            return "·"
        case 3:
            return "•"
        default:
            return "●"
        }
    }
}
