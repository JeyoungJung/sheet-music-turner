import Foundation
import SwiftData

// MARK: - LibraryItem

@Model
final class LibraryItem {
    var id: UUID
    var name: String
    var fileName: String
    var dateAdded: Date
    var dateModified: Date
    var pageCount: Int
    
    @Relationship(inverse: \Folder.items)
    var folder: Folder?
    
    init(name: String, fileName: String, pageCount: Int) {
        self.id = UUID()
        self.name = name
        self.fileName = fileName
        self.dateAdded = Date()
        self.dateModified = Date()
        self.pageCount = pageCount
    }
    
    var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}

// MARK: - Folder

@Model
final class Folder {
    var id: UUID
    var name: String
    var dateCreated: Date
    var sortOrder: Int
    
    @Relationship
    var items: [LibraryItem]
    
    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.dateCreated = Date()
        self.sortOrder = sortOrder
        self.items = []
    }
}

// MARK: - PageDrawing

@Model
final class PageDrawing {
    var id: UUID
    var libraryItemID: UUID
    var pageIndex: Int
    @Attribute(.externalStorage)
    var drawingData: Data
    var lastModified: Date
    
    init(libraryItemID: UUID, pageIndex: Int, drawingData: Data = Data()) {
        self.id = UUID()
        self.libraryItemID = libraryItemID
        self.pageIndex = pageIndex
        self.drawingData = drawingData
        self.lastModified = Date()
    }
}

// MARK: - Setlist

@Model
final class Setlist {
    var id: UUID
    var name: String
    var dateCreated: Date
    var dateModified: Date
    
    @Relationship(deleteRule: .cascade, inverse: \SetlistEntry.setlist)
    var entries: [SetlistEntry]
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.dateCreated = Date()
        self.dateModified = Date()
        self.entries = []
    }
}

// MARK: - SetlistEntry

@Model
final class SetlistEntry {
    var id: UUID
    var sortOrder: Int
    
    var setlist: Setlist?
    
    @Relationship
    var libraryItem: LibraryItem?
    
    init(libraryItem: LibraryItem, sortOrder: Int) {
        self.id = UUID()
        self.sortOrder = sortOrder
        self.libraryItem = libraryItem
    }
}
