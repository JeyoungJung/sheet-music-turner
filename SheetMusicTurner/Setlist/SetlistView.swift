import SwiftUI
import SwiftData

struct SetlistView: View {

    let tabPicker: AnyView

    @Query(sort: \Setlist.dateCreated) private var setlists: [Setlist]

    @Environment(\.modelContext) private var modelContext

    @State private var showingCreateSetlistAlert = false
    @State private var showingDeleteSetlistConfirmation = false
    @State private var showingRenameSetlistAlert = false
    @State private var textFieldValue = ""
    @State private var setlistPendingDeletion: Setlist?
    @State private var setlistPendingRename: Setlist?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Theme.Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        // No sidebar to toggle on Setlists tab — placeholder for visual symmetry
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Theme.Colors.gold)
                    }
                    .hidden()

                    Spacer()

                    Button {
                        beginSetlistCreation()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Theme.Colors.gold)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, 7)
                .padding(.bottom, 4)

                if setlists.isEmpty {
                    emptyStateView
                } else {
                    setlistGrid
                }
            }
            .background(Theme.Colors.canvas)
            .overlay(alignment: .top) {
                tabPicker
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.Colors.gold)
        .alert("New Setlist", isPresented: $showingCreateSetlistAlert, actions: {
            TextField("Setlist Name", text: $textFieldValue)

            Button("Create") {
                createSetlist()
            }
            .keyboardShortcut(.defaultAction)

            Button("Cancel", role: .cancel) {
                textFieldValue = ""
            }
        }, message: {
            Text("Enter a name for the new setlist.")
        })
        .alert("Rename Setlist", isPresented: $showingRenameSetlistAlert, actions: {
            TextField("Setlist Name", text: $textFieldValue)

            Button("Save") {
                renameSetlist()
            }
            .keyboardShortcut(.defaultAction)

            Button("Cancel", role: .cancel) {
                setlistPendingRename = nil
                textFieldValue = ""
            }
        }, message: {
            Text("Update the setlist name.")
        })
        .confirmationDialog(
            "Delete Setlist?",
            isPresented: $showingDeleteSetlistConfirmation,
            titleVisibility: .visible,
            presenting: setlistPendingDeletion
        ) { setlist in
            Button("Delete Setlist", role: .destructive) {
                deleteSetlist(setlist)
            }

            Button("Cancel", role: .cancel) {
                setlistPendingDeletion = nil
            }
        } message: { setlist in
            Text("Delete \"\(setlist.name)\"? This removes all pieces from the setlist.")
        }
    }

    private var setlistGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(setlists) { setlist in
                    NavigationLink(destination: SetlistDetailView(setlist: setlist)) {
                        SetlistCard(setlist: setlist)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            beginSetlistRename(setlist)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            confirmDeletion(for: setlist)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            headline: "No Setlists",
            message: "Tap + to build an ordered program from your library."
        )
    }

    private var trimmedTextFieldValue: String {
        textFieldValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginSetlistCreation() {
        textFieldValue = "New Setlist"
        showingCreateSetlistAlert = true
    }

    private func createSetlist() {
        let name = trimmedTextFieldValue
        guard !name.isEmpty else { return }

        modelContext.insert(Setlist(name: name))
        textFieldValue = ""
    }

    private func beginSetlistRename(_ setlist: Setlist) {
        setlistPendingRename = setlist
        textFieldValue = setlist.name
        showingRenameSetlistAlert = true
    }

    private func renameSetlist() {
        let name = trimmedTextFieldValue
        guard !name.isEmpty, let setlist = setlistPendingRename else { return }
        setlist.name = name
        setlist.dateModified = Date()
        setlistPendingRename = nil
        textFieldValue = ""
    }

    private func confirmDeletion(for setlist: Setlist) {
        setlistPendingDeletion = setlist
        showingDeleteSetlistConfirmation = true
    }

    private func deleteSetlist(_ setlist: Setlist) {
        modelContext.delete(setlist)
        setlistPendingDeletion = nil
    }
}

// MARK: - Setlist Card

struct SetlistCard: View {
    let setlist: Setlist
    @State private var thumbnail: UIImage?

    private var sortedEntries: [SetlistEntry] {
        setlist.entries.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var firstLibraryItem: LibraryItem? {
        sortedEntries.first(where: { $0.libraryItem != nil })?.libraryItem
    }

    private var pieceCountText: String {
        let count = setlist.entries.count
        return count == 1 ? "1 piece" : "\(count) pieces"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Dimensions.innerSpacing) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius - 4, style: .continuous)
                    .fill(Theme.Colors.separator)
                    .aspectRatio(0.77, contentMode: .fit)
                    .overlay {
                        if let thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius - 4, style: .continuous))
                        } else {
                            VStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 36))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }

                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.Colors.gold)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
            .task(id: firstLibraryItem?.id) {
                await loadThumbnail()
            }

            Text(setlist.name)
                .font(Theme.body())
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

            Text(pieceCountText)
                .font(Theme.caption())
                .foregroundColor(Theme.Colors.textSecondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
    }

    private func loadThumbnail() async {
        guard let item = firstLibraryItem else {
            thumbnail = nil
            return
        }
        let url = item.fileURL
        let image = await Task.detached(priority: .utility) {
            PageImageRenderer.renderPageSync(
                documentURL: url,
                pageIndex: 0,
                targetSize: CGSize(width: 280, height: 364)
            )
        }.value
        if let image {
            thumbnail = image
        }
    }
}
