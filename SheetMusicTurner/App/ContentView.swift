import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: AppTab = .library

    var body: some View {
        let picker = AnyView(tabPicker)
        Group {
            switch selectedTab {
            case .library:
                LibraryView(tabPicker: picker)
            case .setlists:
                SetlistView(tabPicker: picker)
            }
        }
        .tint(Theme.Colors.gold)
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(Theme.Motion.smoothSpring) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(Theme.body())
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab
                                ? Theme.Colors.surface.opacity(0.9)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 6)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case library
    case setlists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "Library"
        case .setlists: return "Setlists"
        }
    }
}
