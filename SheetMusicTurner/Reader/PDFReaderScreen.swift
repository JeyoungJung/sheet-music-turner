import SwiftUI
import CoreGraphics
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

enum PDFReaderAlert: Equatable {
    case cannotOpen
    case noPages

    var title: String {
        "Cannot Open PDF"
    }

    var message: String {
        switch self {
        case .cannotOpen:
            return "This file could not be opened."
        case .noPages:
            return "This PDF has no pages."
        }
    }
}

struct PDFReaderScreen: View {

    private let item: LibraryItem
    private let setlistPlayer: SetlistPlayer?

    @State private var currentItem: LibraryItem
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 0
    @State private var isAnnotating: Bool = false
    @State private var showAnnotationControls: Bool = false
    @State private var activeAnnotationTool: AnnotationTool = .pen
    @State private var activeAnnotationColor: AnnotationToolbarColor = .black
    @State private var activeAnnotationThickness: CGFloat = 1
    @State private var isWideLayout: Bool = false
    @State private var isFullscreen: Bool = false
    @State private var readerAlert: PDFReaderAlert?
    @State private var pendingPagePosition: PendingPagePosition?
    @StateObject private var coordinator = PDFViewCoordinator()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager
    @FocusState private var isReaderFocused: Bool

    init(item: LibraryItem) {
        self.item = item
        self.setlistPlayer = nil
        _currentItem = State(initialValue: item)
    }

    init(setlistPlayer: SetlistPlayer) {
        guard let item = setlistPlayer.currentLibraryItem else {
            fatalError("SetlistPlayer requires at least one playable entry.")
        }

        self.item = item
        self.setlistPlayer = setlistPlayer
        _currentItem = State(initialValue: item)
    }

    var body: some View {
        GeometryReader { geometry in

            ZStack {
                Theme.Colors.canvas
                    .ignoresSafeArea()

                configuredPDFReaderView
                    .ignoresSafeArea()

                if isFullscreen {
                    EmptyView()
                } else {
                    annotationToolbarOverlay

                    annotationToggle

                    pieceNameBar
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                if !isFullscreen {
                    pageIndicator(isWide: isWideLayout)
                        .zIndex(10)
                }
            }
            .onAppear {
                updateLayout(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                updateLayout(for: newSize)
            }
        }
        .ignoresSafeArea()
        .focusable()
        .focused($isReaderFocused)
        .onKeyPress(.rightArrow) { goToNextPage(); return .handled }
        .onKeyPress(.leftArrow) { goToPreviousPage(); return .handled }
        .onKeyPress(.space) { goToNextPage(); return .handled }
        .onKeyPress(.return) { goToNextPage(); return .handled }
        .onAppear {
            isReaderFocused = true
            if isSetlistMode {
                setIdleTimerDisabled(true)
            }
        }
        .onDisappear {
            coordinator.saveAnnotationsNow()
            if isSetlistMode {
                setIdleTimerDisabled(false)
            }
        }
        .onChange(of: isAnnotating) {
            coordinator.isAnnotating = isAnnotating
            coordinator.canvasUndoManager = undoManager
            coordinator.setActiveTool(activeAnnotationTool)
            coordinator.setColor(activeAnnotationColor.colorValue)
            coordinator.setThickness(activeAnnotationThickness)

            if !isAnnotating {
                coordinator.saveAnnotationsNow()
                showAnnotationControls = false
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                coordinator.saveAnnotationsNow()
            }
        }
        .onChange(of: totalPages) { _, _ in
            applyPendingPagePositionIfNeeded()
        }
        .onChange(of: currentPage) { _, newPage in
            prefetchNextEntryIfNeeded(currentPage: newPage)
        }
        .alert(readerAlert?.title ?? "", isPresented: isShowingReaderAlert) {
            Button("OK") {
                readerAlert = nil
            }
        } message: {
            Text(readerAlert?.message ?? "")
                .font(Theme.body())
                .multilineTextAlignment(.leading)
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
    }

    private var configuredPDFReaderView: some View {
        let _ = configureCoordinator()

        return AnyView(PDFReaderView(
            documentURL: currentItem.fileURL,
            currentPage: $currentPage,
            totalPages: $totalPages,
            isAnnotating: $isAnnotating,
            isFullscreen: $isFullscreen,
            readerAlert: $readerAlert,
            undoManager: undoManager,
            coordinator: coordinator,
            isWide: isWideLayout,
            onTapZone: { zone in
                if isFullscreen {
                    switch zone {
                    case 0: goToPreviousPage()
                    case 2: goToNextPage()
                    default:
                        withAnimation(Theme.AnimationTokens.standard) {
                            isFullscreen = false
                        }
                    }
                } else {
                    switch zone {
                    case 0: goToPreviousPage()
                    case 2: goToNextPage()
                    default:
                        withAnimation(Theme.AnimationTokens.standard) {
                            showAnnotationControls.toggle()
                        }
                    }
                }
            }
        )
        .padding(.bottom, isAnnotating ? AnnotationToolbar.height : 0))
    }

    private func pageIndicator(isWide: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Colors.separator.opacity(0.5))
                .frame(height: Theme.Layout.hairline)
            HStack(spacing: 0) {
                Spacer()
                if visibleTotalPages > 0 {
                    Text(pageIndicatorDisplayText(isWide: isWide))
                        .font(Theme.number())
                        .foregroundColor(Theme.Colors.textPrimary)
                        .tracking(0.5)
                        .padding(.trailing, Theme.Spacing.md)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Theme.Colors.surface)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.Colors.separator.opacity(0.3))
                    Rectangle()
                        .fill(Theme.Colors.gold)
                        .frame(width: geometry.size.width * pageIndicatorProgress)
                }
            }
            .frame(height: 2)
        }
        .background(Theme.Colors.surface)
        .padding(.bottom, isAnnotating ? AnnotationToolbar.height : 0)
    }

    private var pageIndicatorProgress: CGFloat {
        guard visibleTotalPages > 0 else { return 0 }
        return min(max(CGFloat(currentPage + 1) / CGFloat(visibleTotalPages), 0), 1)
    }

    private var visibleTotalPages: Int {
        max(totalPages, coordinator.totalPageCount)
    }

    private func pageIndicatorDisplayText(isWide: Bool) -> String {
        let pageLabel = basePageIndicatorDisplayText(isWide: isWide)

        guard let setlistPlayer else {
            return pageLabel
        }

        return "Piece \(currentPieceNumber(for: setlistPlayer))/\(setlistPlayer.totalEntries) — \(pageLabel)"
    }

    private func basePageIndicatorDisplayText(isWide: Bool) -> String {
        let pageNumber = currentPage + 1

        guard isWide, visibleTotalPages > 1 else {
            return "\(pageNumber) / \(visibleTotalPages)"
        }

        if pageNumber == 1 {
            return "1 / \(visibleTotalPages)"
        }

        let spreadStart = pageNumber.isMultiple(of: 2) ? pageNumber : pageNumber - 1
        let spreadEnd = min(spreadStart + 1, visibleTotalPages)

        if spreadStart == spreadEnd {
            return "\(spreadStart) / \(visibleTotalPages)"
        }

        return "\(spreadStart)-\(spreadEnd) / \(visibleTotalPages)"
    }

    private func updateLayout(for size: CGSize) {
        isWideLayout = size.width > size.height
    }

    private func configureCoordinator() {
        coordinator.configureAnnotationPersistence(modelContext: modelContext, libraryItemID: currentItem.id)
        coordinator.canvasUndoManager = undoManager
        coordinator.isAnnotating = isAnnotating
        coordinator.setActiveTool(activeAnnotationTool)
        coordinator.setColor(activeAnnotationColor.colorValue)
        coordinator.setThickness(activeAnnotationThickness)
    }

    private var isShowingReaderAlert: Binding<Bool> {
        Binding(
            get: { readerAlert != nil },
            set: { isPresented in
                if !isPresented {
                    readerAlert = nil
                }
            }
        )
    }

    private var isSetlistMode: Bool {
        setlistPlayer != nil
    }

    private func currentPieceNumber(for setlistPlayer: SetlistPlayer) -> Int {
        guard setlistPlayer.totalEntries > 0 else {
            return 0
        }

        return min(max(setlistPlayer.currentEntryIndex + 1, 1), setlistPlayer.totalEntries)
    }

    private func goToNextPage() {
        if advanceToNextEntryIfNeeded() {
            return
        }

        coordinator.goToNextPage()
    }

    private func goToPreviousPage() {
        if retreatToPreviousEntryIfNeeded() {
            return
        }

        coordinator.goToPreviousPage()
    }

    private func advanceToNextEntryIfNeeded() -> Bool {
        let liveTotalPages = max(totalPages, coordinator.totalPageCount)
        let liveCurrentPage = min(max(coordinator.currentPageIndex, 0), max(liveTotalPages - 1, 0))

        guard let setlistPlayer,
              liveTotalPages > 0,
              liveCurrentPage >= liveTotalPages - 1,
              setlistPlayer.hasNextEntry else {
            return false
        }

        transitionSetlistEntry(using: setlistPlayer.nextEntry, targetPagePosition: .first)
        return true
    }

    private func retreatToPreviousEntryIfNeeded() -> Bool {
        let liveTotalPages = max(totalPages, coordinator.totalPageCount)
        let liveCurrentPage = min(max(coordinator.currentPageIndex, 0), max(liveTotalPages - 1, 0))

        guard let setlistPlayer,
              liveTotalPages > 0,
              liveCurrentPage == 0,
              setlistPlayer.hasPreviousEntry else {
            return false
        }

        transitionSetlistEntry(using: setlistPlayer.previousEntry, targetPagePosition: .last)
        return true
    }

    private func transitionSetlistEntry(using advance: () -> Void, targetPagePosition: PendingPagePosition) {
        coordinator.saveAnnotationsNow()
        coordinator.canvasManager.removeAllCanvases()
        coordinator.loadedDocumentURL = nil
        isAnnotating = false
        readerAlert = nil
        pendingPagePosition = targetPagePosition
        currentPage = 0
        totalPages = 0

        advance()

        if let nextItem = setlistPlayer?.currentLibraryItem {
            coordinator.configureAnnotationPersistence(modelContext: modelContext, libraryItemID: nextItem.id)
            currentItem = nextItem

            if !applyPrefetchedDocumentIfAvailable(for: nextItem) {
                loadDocumentForCurrentSetlistItem(nextItem)
            }
        } else {
            coordinator.prefetchedDocumentURL = nil
            coordinator.prefetchedPageCount = nil
        }
    }

    @discardableResult
    private func applyPrefetchedDocumentIfAvailable(for item: LibraryItem) -> Bool {
        guard coordinator.prefetchedDocumentURL == item.fileURL,
              let prefetchedPageCount = coordinator.prefetchedPageCount,
              prefetchedPageCount > 0,
              let viewer = coordinator.viewer else {
            return false
        }

        defer {
            coordinator.prefetchedDocumentURL = nil
            coordinator.prefetchedPageCount = nil
        }

        coordinator.configureAnnotationPersistence(modelContext: modelContext, libraryItemID: item.id)
        coordinator.resetForDocument(item.fileURL)
        totalPages = prefetchedPageCount
        currentPage = 0
        viewer.loadDocument(url: item.fileURL, pageCount: prefetchedPageCount)
        applyPendingPagePositionIfNeeded()
        return true
    }

    private func loadDocumentForCurrentSetlistItem(_ item: LibraryItem) {
        guard let viewer = coordinator.viewer else { return }

        guard let cgDocument = CGPDFDocument(item.fileURL as CFURL) else {
            readerAlert = .cannotOpen
            totalPages = 0
            return
        }

        let pageCount = cgDocument.numberOfPages
        guard pageCount > 0 else {
            readerAlert = .noPages
            totalPages = 0
            return
        }

        readerAlert = nil
        coordinator.resetForDocument(item.fileURL)
        totalPages = pageCount
        currentPage = 0
        viewer.loadDocument(url: item.fileURL, pageCount: pageCount)
        applyPendingPagePositionIfNeeded()
    }

    private func applyPendingPagePositionIfNeeded() {
        guard let pendingPagePosition, totalPages > 0 else { return }

        switch pendingPagePosition {
        case .first:
            coordinator.goToPage(0)
        case .last:
            coordinator.goToPage(totalPages - 1)
        }

        self.pendingPagePosition = nil
    }

    private func prefetchNextEntryIfNeeded(currentPage: Int) {
        guard let setlistPlayer,
              totalPages > 0,
              currentPage >= max(totalPages - 2, 0),
              let nextItem = setlistPlayer.nextLibraryItem else {
            return
        }

        let nextURL = nextItem.fileURL

        guard coordinator.prefetchedDocumentURL != nextURL else {
            return
        }

        coordinator.prefetchedDocumentURL = nextURL
        coordinator.prefetchedPageCount = nil

        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgDocument = CGPDFDocument(nextURL as CFURL) else { return }
            let pageCount = cgDocument.numberOfPages
            guard pageCount > 0 else { return }

            // Pre-render the first page of the next document
            let targetSize = UIScreen.main.bounds.size
            coordinator.pageCache.prerender(documentURL: nextURL, pageIndices: [0], targetSize: targetSize)

            DispatchQueue.main.async {
                guard coordinator.prefetchedDocumentURL == nextURL else { return }
                coordinator.prefetchedPageCount = pageCount
            }
        }
    }

    private func setIdleTimerDisabled(_ isDisabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = isDisabled
        #endif
    }

    private var annotationToolbarOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            if isAnnotating {
                AnnotationToolbar(
                    activeTool: $activeAnnotationTool,
                    activeColor: $activeAnnotationColor,
                    activeThickness: $activeAnnotationThickness,
                    onToolChanged: { coordinator.setActiveTool($0) },
                    onColorChanged: { coordinator.setColor($0) },
                    onThicknessChanged: { coordinator.setThickness($0) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(Theme.AnimationTokens.standard, value: isAnnotating)
    }

    private var annotationToggle: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.body())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }

                Spacer()

                Button {
                    isAnnotating.toggle()
                } label: {
                    Image(systemName: isAnnotating ? "pencil" : "pencil.slash")
                        .foregroundStyle(isAnnotating ? Theme.Colors.gold : Theme.Colors.textSecondary)
                        .padding(Theme.Spacing.sm)
                }

                Button {
                    withAnimation(Theme.AnimationTokens.standard) {
                        isAnnotating = false
                        showAnnotationControls = false
                        isFullscreen = true
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(Theme.body())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.top, Theme.Spacing.xs)
            Spacer()
        }
        .animation(Theme.AnimationTokens.standard, value: showAnnotationControls)
        .animation(Theme.AnimationTokens.standard, value: isAnnotating)
    }

    private var pieceNameBar: some View {
        VStack {
            if let setlistPlayer, let name = setlistPlayer.currentLibraryItem?.name {
                HStack {
                    Text(name)
                        .font(Theme.caption())
                        .foregroundColor(Theme.Colors.textSecondary)
                        .textCase(.uppercase)
                        .kerning(0.3)
                        .lineLimit(1)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.xs)
                    Spacer()
                }
            }
            Spacer()
        }
    }
}

private enum PendingPagePosition {
    case first
    case last
}
