import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            SetlistView()
                .tabItem {
                    Label("Setlists", systemImage: "list.bullet")
                }
        }
        .tint(Theme.Colors.gold)
    }
}
