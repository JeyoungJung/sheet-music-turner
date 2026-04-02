import Foundation
import SwiftUI

final class SetlistPlayer: ObservableObject {
    var entries: [SetlistEntry]
    @Published var currentEntryIndex: Int

    init(setlist: Setlist) {
        self.entries = SetlistPlayer.sortedEntries(from: setlist.entries)
        self.currentEntryIndex = SetlistPlayer.initialEntryIndex(in: self.entries) ?? 0
    }

    init(entries: [SetlistEntry], currentEntryIndex: Int? = nil) {
        self.entries = SetlistPlayer.sortedEntries(from: entries)
        self.currentEntryIndex = currentEntryIndex ?? SetlistPlayer.initialEntryIndex(in: self.entries) ?? 0
    }

    var currentLibraryItem: LibraryItem? {
        libraryItem(at: currentEntryIndex)
    }

    var hasNextEntry: Bool {
        nextPlayableEntryIndex(from: currentEntryIndex) != nil
    }

    var hasPreviousEntry: Bool {
        previousPlayableEntryIndex(from: currentEntryIndex) != nil
    }

    var totalEntries: Int {
        entries.count
    }

    var progressLabel: String {
        guard totalEntries > 0 else {
            return "Piece 0 of 0"
        }

        let displayIndex = min(max(currentEntryIndex + 1, 1), totalEntries)
        return "Piece \(displayIndex) of \(totalEntries)"
    }

    var nextLibraryItem: LibraryItem? {
        libraryItem(at: nextPlayableEntryIndex(from: currentEntryIndex))
    }

    func nextEntry() {
        guard let nextIndex = nextPlayableEntryIndex(from: currentEntryIndex) else { return }
        currentEntryIndex = nextIndex
    }

    func previousEntry() {
        guard let previousIndex = previousPlayableEntryIndex(from: currentEntryIndex) else { return }
        currentEntryIndex = previousIndex
    }

    private func libraryItem(at index: Int?) -> LibraryItem? {
        guard let index, entries.indices.contains(index) else {
            return nil
        }

        return entries[index].libraryItem
    }

    private func nextPlayableEntryIndex(from index: Int) -> Int? {
        guard !entries.isEmpty else { return nil }

        let startIndex = max(index + 1, 0)

        for candidateIndex in startIndex..<entries.count where entries[candidateIndex].libraryItem != nil {
            return candidateIndex
        }

        return nil
    }

    private func previousPlayableEntryIndex(from index: Int) -> Int? {
        guard !entries.isEmpty, index > 0 else { return nil }

        for candidateIndex in stride(from: index - 1, through: 0, by: -1) where entries[candidateIndex].libraryItem != nil {
            return candidateIndex
        }

        return nil
    }

    private static func initialEntryIndex(in entries: [SetlistEntry]) -> Int? {
        entries.firstIndex { $0.libraryItem != nil }
    }

    private static func sortedEntries(from entries: [SetlistEntry]) -> [SetlistEntry] {
        entries.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return lhs.sortOrder < rhs.sortOrder
        }
    }
}
