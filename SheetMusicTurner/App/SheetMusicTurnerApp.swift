import SwiftUI
import SwiftData

@main
struct SheetMusicTurnerApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(.sheetMusicContainer)
    }
}
