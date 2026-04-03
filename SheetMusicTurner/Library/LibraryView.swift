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
       @State private var showingRenameScoreAlert = false
       @State private var itemPendingRename: LibraryItem?
       @State private var isSelecting = false
       @State private var selectedItems: Set<UUID> = []
        @State private var showingBatchMoveSheet = false
    @State private var showSidebar: Bool = true

       @Environment(\.modelContext) private var modelContext

       private let sidebarWidth: CGFloat = 320

       var body: some View {
           HStack(spacing: 0) {
               if showSidebar {
                   sidebarView
                       .frame(width: sidebarWidth)
                       .transition(.move(edge: .leading))

                   Divider()
               }

               detailView
                   .frame(maxWidth: .infinity)
           }
           .tint(Theme.Colors.gold)
           .fullScreenCover(item: $selectedScoreItem) { item in
               PDFReaderScreen(item: item)
           }
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
        VStack(spacing: 0) {
            // Custom header — sidebar toggle at absolute top-left
            HStack {
                Button {
                    withAnimation(Theme.Motion.smoothSpring) {
                        showSidebar = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.gold)
                }

                Spacer()

                Button {
                    beginFolderCreation()
                } label: {
                    Image(systemName: "plus.rectangle.on.folder")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.gold)
                }

                Button {
                    showingImporter = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.gold)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.sm)

            // Large title
            Text("Library")
                .font(.largeTitle.bold())
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.sm)

            // Search bar
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .font(Theme.caption())
                TextField("Search", text: $searchText)
                    .font(Theme.body())
                    .foregroundColor(Theme.Colors.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.textSecondary)
                            .font(Theme.caption())
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.separator.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)

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
        }
        .background(Theme.Colors.surface)
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
        VStack(spacing: 0) {
            // Always-visible header row
            detailHeaderRow

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
        .sheet(isPresented: $showingBatchMoveSheet) {
            FolderPickerSheet(
                folders: folders,
                selectedFolder: nil
            ) { folder in
                batchMoveSelectedItems(to: folder)
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
        .alert("Rename Score", isPresented: $showingRenameScoreAlert, actions: {
            TextField("Score Name", text: $textFieldValue)

            Button("Save") {
                renameScore()
            }
            .keyboardShortcut(.defaultAction)

            Button("Cancel", role: .cancel) {
                itemPendingRename = nil
                resetFolderTextInput()
            }
        }, message: {
            Text("Enter a new name for the score.")
        })
    }

    private var detailHeaderRow: some View {
        HStack {
            if !showSidebar {
                Button {
                    withAnimation(Theme.Motion.smoothSpring) {
                        showSidebar = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Theme.Colors.gold)
                }
            }

            Spacer()

            Button {
                withAnimation(Theme.AnimationTokens.standard) {
                    isSelecting.toggle()
                    if !isSelecting { selectedItems.removeAll() }
                }
            } label: {
                Text(isSelecting ? "Done" : "Select")
                    .font(Theme.title1())
                    .foregroundColor(Theme.Colors.gold)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 7)
        .padding(.bottom, 4)
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

        return VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                    ForEach(items) { item in
                        Button {
                            if isSelecting {
                                toggleSelection(item)
                            } else {
                                selectedScoreItem = item
                            }
                        } label: {
                            PDFItemCard(item: item, isSelected: isSelecting && selectedItems.contains(item.id))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !isSelecting {
                                Button("Rename") {
                                    beginScoreRename(item)
                                }

                                Button("Move to…") {
                                    presentFolderPicker(for: item)
                                }

                                Button("Delete", role: .destructive) {
                                    confirmScoreDeletion(item)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }

            if isSelecting && !selectedItems.isEmpty {
                selectionToolbar(items: items)
            }
        }
    }

    private func selectionToolbar(items: [LibraryItem]) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Button {
                if selectedItems.count == items.count {
                    selectedItems.removeAll()
                } else {
                    selectedItems = Set(items.map(\.id))
                }
            } label: {
                Text(selectedItems.count == items.count ? "Deselect All" : "Select All")
                    .font(Theme.title3())
                    .foregroundColor(Theme.Colors.gold)
            }

            Spacer()

            Text("\(selectedItems.count) selected")
                .font(Theme.caption())
                .foregroundColor(Theme.Colors.textSecondary)

            Spacer()

            Button {
                showingBatchMoveSheet = true
            } label: {
                Label("Move to…", systemImage: "folder")
                    .font(Theme.title3())
                    .foregroundColor(Theme.Colors.gold)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.surface)
        .overlay(alignment: .top) { SwissDivider() }
    }

    private func toggleSelection(_ item: LibraryItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
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

    private func batchMoveSelectedItems(to folder: Folder?) {
        for item in allItems where selectedItems.contains(item.id) {
            item.folder = folder
        }
        selectedItems.removeAll()
        isSelecting = false
    }

    private func confirmScoreDeletion(_ item: LibraryItem) {
        itemPendingDeletion = item
        showingDeleteScoreConfirmation = true
    }

    private func beginScoreRename(_ item: LibraryItem) {
        itemPendingRename = item
        textFieldValue = item.name
        showingRenameScoreAlert = true
    }

    private func renameScore() {
        let name = trimmedTextFieldValue
        guard !name.isEmpty, let item = itemPendingRename else { return }
        item.name = name
        itemPendingRename = nil
        resetFolderTextInput()
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
    var isSelected: Bool = false
    @State private var thumbnail: UIImage?

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
                            Text(item.name.prefix(1).uppercased())
                                .font(Theme.display())
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.Colors.gold)
                                .background(Circle().fill(Theme.Colors.surface).padding(2))
                                .padding(10)
                        }
                    }

                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.Colors.gold)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
            .task(id: item.id) {
                await loadThumbnail()
            }

            Text(item.name)
                .font(Theme.body())
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

            Text("\(item.pageCount) pages")
                .font(Theme.caption())
                .foregroundColor(Theme.Colors.textSecondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Dimensions.cardPadding)
        .swissCard()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.Dimensions.cardRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.gold, lineWidth: 2.5)
            }
        }
    }

    private func loadThumbnail() async {
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
