import SwiftData
import PDFKit

extension ModelContainer {
    @MainActor
    static var sheetMusicContainer: ModelContainer = {
        let schema = Schema([
            LibraryItem.self,
            Folder.self,
            PageDrawing.self,
            Setlist.self,
            SetlistEntry.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

}
