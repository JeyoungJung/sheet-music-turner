import SwiftUI
import SwiftData

struct SetlistView: View {

    @Query(sort: \Setlist.dateCreated) private var setlists: [Setlist]

    @Environment(\.modelContext) private var modelContext

    @State private var showingCreateSetlistAlert = false
    @State private var showingDeleteSetlistConfirmation = false
    @State private var textFieldValue = ""
    @State private var setlistPendingDeletion: Setlist?

    var body: some View {
        NavigationStack {
            Group {
                if setlists.isEmpty {
                    emptyStateView
                } else {
                    setlistListView
                }
            }
            .background(Theme.Colors.canvas)
            .navigationTitle("Setlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        beginSetlistCreation()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.Colors.gold)
                    }
                }
            }
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

    private var setlistListView: some View {
        List {
            ForEach(setlists) { setlist in
                NavigationLink(destination: SetlistDetailView(setlist: setlist)) {
                    SetlistRow(setlist: setlist)
                }
                .buttonStyle(.plain)
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
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        confirmDeletion(for: setlist)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        confirmDeletion(for: setlist)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
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

    private func confirmDeletion(for setlist: Setlist) {
        setlistPendingDeletion = setlist
        showingDeleteSetlistConfirmation = true
    }

    private func deleteSetlist(_ setlist: Setlist) {
        modelContext.delete(setlist)
        setlistPendingDeletion = nil
    }
}

private struct SetlistRow: View {
    let setlist: Setlist

    private var pieceCountText: String {
        let count = setlist.entries.count
        return count == 1 ? "1 piece" : "\(count) pieces"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(setlist.name)
                .swissBody()

            Text("\(pieceCountText) · \(setlist.dateCreated.formatted(date: .abbreviated, time: .omitted))")
                .swissCaption()
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
    }
}
