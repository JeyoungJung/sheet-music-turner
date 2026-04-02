import SwiftUI
import SwiftData

struct SetlistDetailView: View {

    let setlist: Setlist

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingPiecePicker = false
    @State private var showingRenameAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPlaybackPlaceholder = false
    @State private var renameText = ""
    @State private var readerPresentation: ReaderPresentation?

    var body: some View {
        List {
            Section {
                setlistSummaryCard
            }
            .listRowInsets(
                EdgeInsets(
                    top: Theme.Spacing.md,
                    leading: Theme.Spacing.md,
                    bottom: Theme.Spacing.xs,
                    trailing: Theme.Spacing.md
                )
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section {
                if sortedEntries.isEmpty {
                    emptyEntriesCard
                        .listRowInsets(
                            EdgeInsets(
                                top: Theme.Spacing.xs,
                                leading: Theme.Spacing.md,
                                bottom: Theme.Spacing.xs,
                                trailing: Theme.Spacing.md
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(sortedEntries) { entry in
                        entryRow(entry)
                            .listRowInsets(
                                EdgeInsets(
                                    top: Theme.Spacing.xs,
                                    leading: Theme.Spacing.md,
                                    bottom: Theme.Spacing.xs,
                                    trailing: Theme.Spacing.md
                                )
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onMove(perform: moveEntries)
                    .onDelete(perform: deleteEntries)
                }
            } header: {
                Text("Pieces")
                    .swissCaption()
                    .padding(.horizontal, Theme.Spacing.md)
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Text("Delete Setlist")
                        .font(Theme.body())
                        .foregroundColor(Theme.Colors.danger)
                }
                .buttonStyle(.plain)
            }
            .listRowInsets(
                EdgeInsets(
                    top: Theme.Spacing.md,
                    leading: Theme.Spacing.md,
                    bottom: Theme.Spacing.lg,
                    trailing: Theme.Spacing.md
                )
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
        .navigationTitle(setlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()

                Button {
                    beginRename()
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(Theme.Colors.gold)
                }

                Button {
                    showingPiecePicker = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Theme.Colors.gold)
                }
            }
        }
        .sheet(isPresented: $showingPiecePicker) {
            PiecePicker(setlist: setlist)
        }
        .alert("Rename Setlist", isPresented: $showingRenameAlert, actions: {
            TextField("Setlist Name", text: $renameText)

            Button("Save") {
                renameSetlist()
            }
            .keyboardShortcut(.defaultAction)

            Button("Cancel", role: .cancel) {
                renameText = setlist.name
            }
        }, message: {
            Text("Update the setlist name.")
        })
        .alert("Playback Coming Soon", isPresented: $showingPlaybackPlaceholder) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add a piece to this setlist to start playback in Task 15.")
        }
        .confirmationDialog(
            "Delete Setlist?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Setlist", role: .destructive) {
                deleteSetlist()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(setlist.name)\"? This removes every piece in the setlist.")
        }
        .fullScreenCover(item: $readerPresentation) { presentation in
            switch presentation {
            case .single(let libraryItem):
                PDFReaderScreen(item: libraryItem)
            case .setlist(let setlist):
                PDFReaderScreen(setlistPlayer: SetlistPlayer(setlist: setlist))
            }
        }
    }

    private var sortedEntries: [SetlistEntry] {
        setlist.entries.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var pieceCountText: String {
        let count = sortedEntries.count
        return count == 1 ? "1 piece" : "\(count) pieces"
    }

    private var setlistSummaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(setlist.name)
                    .swissHeadline()

                Text(pieceCountText)
                    .swissCaption()

                Text("Updated \(setlist.dateModified.formatted(date: .abbreviated, time: .omitted))")
                    .swissCaption()
            }

            playButton
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius, style: .continuous))
        .onLongPressGesture {
            beginRename()
        }
    }

    @ViewBuilder
    private var playButton: some View {
        if sortedEntries.contains(where: { $0.libraryItem != nil }) {
            Button {
                readerPresentation = .setlist(setlist)
            } label: {
                SetlistActionCard(title: "Play", subtitle: "Start continuous playback for this setlist", systemImage: "play.fill")
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showingPlaybackPlaceholder = true
            } label: {
                SetlistActionCard(title: "Play", subtitle: "Add a score before starting playback", systemImage: "play.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyEntriesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("No Pieces")
                .swissBody()

            Text("Tap + to add scores from your library.")
                .swissCaption()
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
    }

    @ViewBuilder
    private func entryRow(_ entry: SetlistEntry) -> some View {
        if let libraryItem = entry.libraryItem {
            Button {
                readerPresentation = .single(libraryItem)
            } label: {
                SetlistEntryRow(entry: entry, libraryItem: libraryItem)
            }
            .buttonStyle(.plain)
        } else {
            SetlistMissingEntryRow(entry: entry)
        }
    }

    private func beginRename() {
        renameText = setlist.name
        showingRenameAlert = true
    }

    private func renameSetlist() {
        let trimmedName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        setlist.name = trimmedName
        touchSetlist()
    }

    private func moveEntries(from source: IndexSet, to destination: Int) {
        var reorderedEntries = sortedEntries
        reorderedEntries.move(fromOffsets: source, toOffset: destination)

        for (index, entry) in reorderedEntries.enumerated() {
            entry.sortOrder = index
        }

        setlist.entries = reorderedEntries
        touchSetlist()
    }

    private func deleteEntries(at offsets: IndexSet) {
        let entriesToDelete = offsets.map { sortedEntries[$0] }

        removeEntries(entriesToDelete)
        touchSetlist()
    }

    private func deleteEntry(_ entry: SetlistEntry) {
        removeEntries([entry])
        touchSetlist()
    }

    private func removeEntries(_ entries: [SetlistEntry]) {
        let entryIDs = Set(entries.map(\.id))

        setlist.entries.removeAll { entry in
            entryIDs.contains(entry.id)
        }

        for entry in entries {
            modelContext.delete(entry)
        }

        let remainingEntries = setlist.entries.sorted { $0.sortOrder < $1.sortOrder }

        for (index, entry) in remainingEntries.enumerated() {
            entry.sortOrder = index
        }

        setlist.entries = remainingEntries
    }

    private func touchSetlist() {
        setlist.dateModified = Date()
    }

    private func deleteSetlist() {
        modelContext.delete(setlist)
        dismiss()
    }
}

private struct SetlistActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundColor(Theme.Colors.gold)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .swissBody()

                Text(subtitle)
                    .swissCaption()
            }
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
    }
}

private struct SetlistEntryRow: View {
    let entry: SetlistEntry
    let libraryItem: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(libraryItem.name)
                .swissBody()

            Text("\(libraryItem.pageCount) \(libraryItem.pageCount == 1 ? "page" : "pages") · #\(entry.sortOrder + 1)")
                .swissCaption()
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
    }
}

private struct SetlistMissingEntryRow: View {
    let entry: SetlistEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Missing Score")
                .swissBody()

            Text("#\(entry.sortOrder + 1)")
                .swissCaption()
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
    }
}

enum ReaderPresentation: Identifiable {
    case single(LibraryItem)
    case setlist(Setlist)

    var id: String {
        switch self {
        case .single(let item):
            return "single-\(item.id)"
        case .setlist(let setlist):
            return "setlist-\(setlist.id)"
        }
    }
}
