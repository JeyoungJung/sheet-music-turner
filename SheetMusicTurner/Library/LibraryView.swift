import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {

    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @Query(sort: \LibraryItem.dateAdded, order: .reverse) private var allItems: [LibraryItem]

    private var limitedItems: [LibraryItem] {
        Array(allItems.prefix(500))
    }

     @State private var selectedFolder: FolderSelection? = .allScores
     @State private var showingImporter = false
     @State private var importError: String? = nil
     @State private var showingImportError = false
     @State private var showingCreateFolderAlert = false
     @State private var showingRenameFolderAlert = false
     @State private var showingDeleteFolderConfirmation = false
     @State private var showingFolderPickerSheet = false
      @State private var showingDeleteScoreConfirmation = false
     @State private var textFieldValue = ""
     @State private var folderPendingRename: Folder?
     @State private var folderPendingDeletion: Folder?
     @State private var itemPendingMove: LibraryItem?
     @State private var itemPendingDeletion: LibraryItem?
      @State private var searchText: String = ""
       @State private var selectedScoreItem: LibraryItem?

     @Environment(\.modelContext) private var modelContext

     var body: some View {
         NavigationSplitView {
              sidebarView
          } detail: {
              detailView
          }
           .navigationSplitViewStyle(.balanced)
           .tint(Theme.Colors.gold)
           .fullScreenCover(item: $selectedScoreItem) { item in
               PDFReaderScreen(item: item)
            }
           .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
         .fileImporter(
             isPresented: $showingImporter,
              allowedContentTypes: [.pdf, .image],
              allowsMultipleSelection: false
         ) { result in
             handleImportResult(result)
         }
         .alert("Import Failed", isPresented: $showingImportError, actions: {
             Button("OK", role: .cancel) {}
         }, message: {
             Text(importError ?? "Unknown error")
         })
     }

    private var sidebarView: some View {
        List(selection: $selectedFolder) {
            Label("All Scores", systemImage: "music.note.list")
                .swissBody()
                .tag(FolderSelection.allScores)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))

            Label("Unfiled", systemImage: "tray")
                .swissBody()
                .tag(FolderSelection.unfiled)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))

            if !folders.isEmpty {
                Section {
                    ForEach(folders) { folder in
                        Label(folder.name, systemImage: "folder")
                            .swissBody()
                            .tag(FolderSelection.folder(folder))
                            .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
                            .contextMenu {
                                Button("Rename") {
                                    beginFolderRename(folder)
                                }

                                Button("Delete", role: .destructive) {
                                    confirmFolderDeletion(folder)
                                }
                            }
                    }
                } header: {
                    Text("Folders")
                        .swissCaption()
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    beginFolderCreation()
                } label: {
                    Image(systemName: "plus.rectangle.on.folder")
                        .foregroundColor(Theme.Colors.gold)
                }

                Button {
                    showingImporter = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Theme.Colors.gold)
                }
            }
        }
        .alert("New Folder", isPresented: $showingCreateFolderAlert, actions: {
            TextField("Folder Name", text: $textFieldValue)

            Button("Create") {
                createFolder()
            }
            .keyboardShortcut(.defaultAction)

            Button("Cancel", role: .cancel) {
                resetFolderTextInput()
            }
        }, message: {
            Text("Enter a name for the new folder.")
        })
        .alert("Rename Folder", isPresented: $showingRenameFolderAlert, actions: {
            TextField("Folder Name", text: $textFieldValue)

            Button("Save") {
                renameFolder()
            }
            .keyboardShortcut(.defaultAction)

            Button("Cancel", role: .cancel) {
                folderPendingRename = nil
                resetFolderTextInput()
            }
        }, message: {
            Text("Update the folder name.")
        })
        .confirmationDialog(
            "Delete Folder?",
            isPresented: $showingDeleteFolderConfirmation,
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { folder in
            Button("Delete Folder", role: .destructive) {
                deleteFolder(folder)
            }

            Button("Cancel", role: .cancel) {
                folderPendingDeletion = nil
            }
        } message: { folder in
            Text("Delete \"\(folder.name)\"? Scores in this folder will move to Unfiled.")
        }
    }

    private var detailView: some View {
        Group {
            let items = filteredItems
            if items.isEmpty {
                emptyStateView
            } else {
                pdfGrid(items: items)
            }
        }
        .background(Theme.Colors.canvas)
        .sheet(isPresented: $showingFolderPickerSheet, onDismiss: {
            itemPendingMove = nil
        }) {
            if let itemPendingMove {
                FolderPickerSheet(
                    folders: folders,
                    selectedFolder: itemPendingMove.folder
                ) { folder in
                    moveItem(itemPendingMove, to: folder)
                }
            }
        }
        .confirmationDialog(
            "Delete Score?",
            isPresented: $showingDeleteScoreConfirmation,
            titleVisibility: .visible,
            presenting: itemPendingDeletion
        ) { item in
            Button("Delete Score", role: .destructive) {
                deleteScore(item)
            }

            Button("Cancel", role: .cancel) {
                itemPendingDeletion = nil
            }
        } message: { item in
            Text("Delete \"\(item.name)\" from the library? This also removes the score file from the app.")
        }
    }

     private var emptyStateView: some View {
         Group {
             if !searchText.isEmpty {
                 EmptyStateView(
                     headline: "No Results",
                     message: "No results for \"\(searchText)\"."
                 )
             } else if case .folder(_) = selectedFolder {
                 EmptyStateView(
                     headline: "Empty Folder",
                     message: "No scores in this folder."
                 )
             } else {
                 EmptyStateView(
                     headline: "No Scores",
                     message: "Import a score to get started.",
                     showImportButton: true,
                     onImport: { showingImporter = true }
                 )
             }
         }
     }

    private func pdfGrid(items: [LibraryItem]) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Theme.Spacing.md)
        ]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(items) { item in
                    Button {
                        selectedScoreItem = item
                    } label: {
                        PDFItemCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Move to…") {
                            presentFolderPicker(for: item)
                        }

                        Button("Delete", role: .destructive) {
                            confirmScoreDeletion(item)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

      private var filteredItems: [LibraryItem] {
          let base: [LibraryItem]
          switch selectedFolder {
          case .allScores, .none:
              base = limitedItems
          case .unfiled:
              base = limitedItems.filter { $0.folder == nil }
          case .folder(let folder):
              base = limitedItems.filter { $0.folder?.id == folder.id }
          }
          if searchText.isEmpty { return base }
          return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
      }

    private var trimmedTextFieldValue: String {
        textFieldValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginFolderCreation() {
        textFieldValue = ""
        showingCreateFolderAlert = true
    }

    private func beginFolderRename(_ folder: Folder) {
        folderPendingRename = folder
        textFieldValue = folder.name
        showingRenameFolderAlert = true
    }

    private func confirmFolderDeletion(_ folder: Folder) {
        folderPendingDeletion = folder
        showingDeleteFolderConfirmation = true
    }

    private func createFolder() {
        let name = trimmedTextFieldValue
        guard !name.isEmpty else { return }

        let nextSortOrder = (folders.map(\.sortOrder).max() ?? -1) + 1
        let folder = Folder(name: name, sortOrder: nextSortOrder)
        modelContext.insert(folder)
        resetFolderTextInput()
    }

    private func renameFolder() {
        let name = trimmedTextFieldValue
        guard !name.isEmpty, let folderPendingRename else { return }

        folderPendingRename.name = name
        self.folderPendingRename = nil
        resetFolderTextInput()
    }

    private func deleteFolder(_ folder: Folder) {
        for item in allItems where item.folder?.id == folder.id {
            item.folder = nil
        }

        if case .folder(let selected) = selectedFolder, selected.id == folder.id {
            selectedFolder = .unfiled
        }

        modelContext.delete(folder)
        folderPendingDeletion = nil
    }

    private func resetFolderTextInput() {
        textFieldValue = ""
    }

    private func presentFolderPicker(for item: LibraryItem) {
        itemPendingMove = item
        showingFolderPickerSheet = true
    }

    private func moveItem(_ item: LibraryItem, to folder: Folder?) {
        item.folder = folder
        itemPendingMove = nil
    }

    private func confirmScoreDeletion(_ item: LibraryItem) {
        itemPendingDeletion = item
        showingDeleteScoreConfirmation = true
    }

    private func deleteScore(_ item: LibraryItem) {
        let itemID = item.id
        let drawingDescriptor = FetchDescriptor<PageDrawing>(
            predicate: #Predicate<PageDrawing> { $0.libraryItemID == itemID }
        )
        do {
            let drawings = try modelContext.fetch(drawingDescriptor)
            for drawing in drawings {
                modelContext.delete(drawing)
            }
        } catch {
            print("[LibraryView] Failed to fetch PageDrawings for deletion: \(error)")
        }
        FileStore.deleteScore(item: item)
        modelContext.delete(item)
        itemPendingDeletion = nil
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            let importResult = PDFImporter.handleImport(result: .success(url), context: modelContext)
            switch importResult {
            case .success:
                break
            case .failure(let message):
                importError = message
                showingImportError = true
            }
        }
    }
}

enum FolderSelection: Hashable {
    case allScores
    case unfiled
    case folder(Folder)

    static func == (lhs: FolderSelection, rhs: FolderSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allScores, .allScores), (.unfiled, .unfiled):
            return true
        case let (.folder(lhsFolder), .folder(rhsFolder)):
            return lhsFolder.id == rhsFolder.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .allScores:
            hasher.combine(0)
        case .unfiled:
            hasher.combine(1)
        case .folder(let folder):
            hasher.combine(2)
            hasher.combine(folder.id)
        }
    }
}

struct PDFItemCard: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Dimensions.innerSpacing) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius - 4, style: .continuous)
                    .fill(Theme.Colors.separator)
                    .aspectRatio(0.77, contentMode: .fit)

                Text(item.name.prefix(1).uppercased())
                    .font(Theme.display())
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.Colors.gold)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }

            Text(item.name)
                .font(Theme.body())
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(item.pageCount) pages")
                .font(Theme.caption())
                .foregroundColor(Theme.Colors.textSecondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
    }
}
