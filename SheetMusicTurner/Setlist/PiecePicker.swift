import SwiftUI
import SwiftData

struct PiecePicker: View {

    let setlist: Setlist

    @Query(sort: \LibraryItem.dateAdded, order: .reverse) private var libraryItems: [LibraryItem]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedIDs: Set<UUID> = []

    private var alreadyAddedIDs: Set<UUID> {
        Set(setlist.entries.compactMap { $0.libraryItem?.id })
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    pickerListView
                }
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Add Pieces")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        addSelectedItems()
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                    .foregroundColor(selectedIDs.isEmpty ? DesignTokens.Colors.secondaryText : DesignTokens.Colors.accent)
                }
            }
        }
    }

    private var filteredItems: [LibraryItem] {
        guard !searchText.isEmpty else { return libraryItems }
        return libraryItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var pickerListView: some View {
        List {
            ForEach(filteredItems) { item in
                let alreadyAdded = alreadyAddedIDs.contains(item.id)
                let isSelected = selectedIDs.contains(item.id)

                Button {
                    if isSelected {
                        selectedIDs.remove(item.id)
                    } else {
                        selectedIDs.insert(item.id)
                    }
                } label: {
                    PiecePickerRow(item: item, isSelected: isSelected, alreadyAdded: alreadyAdded)
                }
                .buttonStyle(.plain)
                .listRowInsets(
                    EdgeInsets(
                        top: DesignTokens.Spacing.xs,
                        leading: DesignTokens.Spacing.md,
                        bottom: DesignTokens.Spacing.xs,
                        trailing: DesignTokens.Spacing.md
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.Colors.background)
    }

    private var emptyStateView: some View {
        Group {
            if searchText.isEmpty {
                EmptyStateView(
                    headline: "No Library Scores",
                    message: "Import PDFs in Library before adding them to a setlist."
                )
            } else {
                EmptyStateView(
                    headline: "No Results",
                    message: "No library score matches \"\(searchText)\"."
                )
            }
        }
    }

    private func addSelectedItems() {
        let itemsToAdd = libraryItems.filter { selectedIDs.contains($0.id) }
        for item in itemsToAdd {
            let entry = SetlistEntry(libraryItem: item, sortOrder: setlist.entries.count)
            entry.setlist = setlist
            setlist.entries.append(entry)
            modelContext.insert(entry)
        }
        if !itemsToAdd.isEmpty {
            setlist.dateModified = Date()
        }
    }
}

private struct PiecePickerRow: View {
    let item: LibraryItem
    let isSelected: Bool
    let alreadyAdded: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(item.name)
                    .swissBody()
                    .foregroundColor(alreadyAdded ? DesignTokens.Colors.secondaryText : DesignTokens.Colors.primaryText)

                Text("\(item.pageCount) \(item.pageCount == 1 ? "page" : "pages")")
                    .swissCaption()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if alreadyAdded {
                Image(systemName: "checkmark")
                    .foregroundColor(DesignTokens.Colors.secondaryText)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignTokens.Colors.accent)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(DesignTokens.Colors.secondaryText)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .swissCard()
    }
}
