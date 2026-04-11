import SwiftUI
import CoreGraphics

// MARK: - PDFReaderView

struct PDFReaderView: UIViewControllerRepresentable {

    let documentURL: URL
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var isAnnotating: Bool
    @Binding var isFullscreen: Bool
    @Binding var readerAlert: PDFReaderAlert?
    let undoManager: UndoManager?
    let coordinator: PDFViewCoordinator
    let isWide: Bool

    /// Called by the tap recognizer — context-aware routing happens here.
    var onTapZone: ((Int) -> Void)?

    // MARK: UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> PagedImageViewer {
        let viewer = PagedImageViewer(pageCache: coordinator.pageCache)
        coordinator.viewer = viewer
        viewer.isFullscreen = isFullscreen
        viewer.isAnnotating = isAnnotating
        coordinator.isAnnotating = isAnnotating
        coordinator.canvasUndoManager = undoManager

        // Canvas provider: coordinator's canvas manager provides canvases keyed by page index
        viewer.canvasProvider = { [weak coordinator] pageIndex in
            guard let coordinator else { return nil }
            return coordinator.canvasManager.canvas(for: pageIndex)
        }

        // Canvas detach: save annotations when leaving a page
        viewer.onCanvasWillDetach = { [weak coordinator] pageIndex in
            coordinator?.canvasManager.saveCanvas(for: pageIndex)
        }

        // Page change callback
        viewer.onPageChanged = { [weak coordinator] page, total in
            DispatchQueue.main.async {
                currentPage = page
                totalPages = total
                coordinator?.onPageChanged?(page, total)
            }
        }

        loadDocument(into: viewer)

        return viewer
    }

    func updateUIViewController(_ viewer: PagedImageViewer, context: Context) {
        coordinator.canvasUndoManager = undoManager
        coordinator.isAnnotating = isAnnotating

        viewer.onTapZone = onTapZone

        if viewer.isFullscreen != isFullscreen {
            viewer.isFullscreen = isFullscreen
        }

        if viewer.isAnnotating != isAnnotating {
            viewer.isAnnotating = isAnnotating
        }

        let targetInset: CGFloat = isAnnotating ? AnnotationToolbar.height : 0
        if viewer.annotationBottomInset != targetInset {
            viewer.annotationBottomInset = targetInset
        }

        if coordinator.loadedDocumentURL != documentURL {
            loadDocument(into: viewer)
        }
    }

    func makeCoordinator() -> PDFViewCoordinator {
        coordinator
    }

    private func loadDocument(into viewer: PagedImageViewer) {
        coordinator.resetForDocument(documentURL)
        currentPage = 0

        guard let cgDocument = CGPDFDocument(documentURL as CFURL) else {
            totalPages = 0
            readerAlert = .cannotOpen
            return
        }

        let pageCount = cgDocument.numberOfPages
        guard pageCount > 0 else {
            totalPages = 0
            readerAlert = .noPages
            return
        }

        readerAlert = nil
        totalPages = pageCount

        viewer.loadDocument(url: documentURL, pageCount: pageCount)
    }
}
