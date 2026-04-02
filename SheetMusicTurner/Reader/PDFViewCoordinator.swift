import Foundation

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
import PencilKit
import SwiftData

/// Coordinates page navigation, annotation management, and page image caching
/// for the custom image-based PDF reader (no PDFView dependency).
final class PDFViewCoordinator: NSObject {
    weak var viewer: PagedImageViewer?
    var onPageChanged: ((Int, Int) -> Void)?
    let canvasManager = CanvasManager()
    let pageCache = PageImageCache()
    var loadedDocumentURL: URL?

    var isAnnotating: Bool = false {
        didSet {
            canvasManager.isAnnotating = isAnnotating
        }
    }

    var canvasUndoManager: UndoManager? {
        didSet {
            canvasManager.undoManager = canvasUndoManager
        }
    }

    // Setlist prefetch
    var prefetchedDocumentURL: URL?
    var prefetchedPageCount: Int?

    func configureAnnotationPersistence(modelContext: ModelContext, libraryItemID: UUID) {
        canvasManager.modelContext = modelContext
        canvasManager.libraryItemID = libraryItemID
    }

    func saveAnnotationsNow() {
        canvasManager.saveAllCanvasesNow()
    }

    func resetForDocument(_ documentURL: URL?) {
        loadedDocumentURL = documentURL
        pageCache.invalidate()
    }

    func setActiveTool(_ tool: AnnotationTool) {
        canvasManager.setActiveTool(tool)
        viewer?.activeTool = tool
    }

    func setColor(_ color: AnnotationColorValue) {
        canvasManager.setColor(color)
        viewer?.activeColor = color
    }

    func setThickness(_ thickness: CGFloat) {
        canvasManager.setThickness(thickness)
        viewer?.activeThickness = thickness
    }

    func goToNextPage() {
        viewer?.goToNextPage()
    }

    func goToPreviousPage() {
        viewer?.goToPreviousPage()
    }

    func goToPage(_ index: Int) {
        viewer?.goToPage(index)
    }

    var currentPageIndex: Int {
        viewer?.currentPageIndex ?? 0
    }

    var totalPageCount: Int {
        viewer?.pageCount ?? 0
    }
}

extension PDFViewCoordinator: ObservableObject {}

// MARK: - CanvasManager

/// Manages PencilKit canvases keyed by page index (not PDFPage).
/// Handles drawing persistence, tool application, and canvas lifecycle.
final class CanvasManager: NSObject, PKCanvasViewDelegate {
    private var canvasViews: [Int: ManagedUndoCanvasView] = [:]
    private var pendingSaveWorkItems: [Int: DispatchWorkItem] = [:]
    var isAnnotating = false
    private var activeTool: AnnotationTool = .pen
    private var activeColor: AnnotationColorValue = .black
    private var activeThickness: CGFloat = 1
    private let annotationStore = AnnotationStore()
    private var memoryWarningObserver: NSObjectProtocol?

    weak var undoManager: UndoManager?
    var modelContext: ModelContext?
    var libraryItemID: UUID?

    override init() {
        super.init()
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.purgeOffscreenCanvases()
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    func setActiveTool(_ tool: AnnotationTool) {
        activeTool = tool
        applyToolToAllCanvases()
    }

    func setColor(_ color: AnnotationColorValue) {
        activeColor = color
        applyToolToAllCanvases()
    }

    func setThickness(_ thickness: CGFloat) {
        activeThickness = thickness
        applyToolToAllCanvases()
    }

    /// Returns (or creates) a canvas for the given page index.
    func canvas(for pageIndex: Int) -> ManagedUndoCanvasView {
        if let existing = canvasViews[pageIndex] {
            existing.externalUndoManager = undoManager
            existing.activeTool = activeTool
            applyTool(to: existing)
            applyInputPolicy(to: existing)
            existing.delegate = self
            return existing
        }

        let canvas = ManagedUndoCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.externalUndoManager = undoManager
        canvas.activeTool = activeTool

        if let drawing = loadDrawing(for: pageIndex) {
            canvas.drawing = drawing
        }

        applyTool(to: canvas)
        applyInputPolicy(to: canvas)
        canvas.delegate = self

        canvasViews[pageIndex] = canvas
        return canvas
    }

    /// Save the canvas for the given page index immediately.
    func saveCanvas(for pageIndex: Int) {
        pendingSaveWorkItems[pageIndex]?.cancel()
        pendingSaveWorkItems[pageIndex] = nil
        persistDrawing(for: pageIndex)
    }

    func saveAllCanvasesNow() {
        pendingSaveWorkItems.values.forEach { $0.cancel() }
        pendingSaveWorkItems.removeAll()

        for pageIndex in Array(canvasViews.keys) {
            persistDrawing(for: pageIndex)
        }
    }

    /// Remove all canvases (e.g., when switching documents).
    func removeAllCanvases() {
        saveAllCanvasesNow()
        for (_, canvas) in canvasViews {
            canvas.delegate = nil
            canvas.removeFromSuperview()
        }
        canvasViews.removeAll()
    }

    // MARK: - PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard let entry = canvasViews.first(where: { $0.value === canvasView }) else { return }
        scheduleAutoSave(for: entry.key)
    }

    // MARK: - Private

    private func applyTool(to canvas: PKCanvasView) {
        if let managedCanvas = canvas as? ManagedUndoCanvasView {
            managedCanvas.activeTool = activeTool
        }

        switch activeTool {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: activeColor, width: activeThickness)
        case .eraser:
            canvas.tool = PKEraserTool(.bitmap)
        case .instantEraser:
            canvas.tool = PKEraserTool(.bitmap)
        case .lasso:
            canvas.tool = PKLassoTool()
        }
    }

    private func applyInputPolicy(to canvas: PKCanvasView) {
        guard isAnnotating else {
            canvas.isUserInteractionEnabled = false
            canvas.drawingPolicy = .pencilOnly
            return
        }

        canvas.isUserInteractionEnabled = true
        canvas.drawingPolicy = (activeTool == .eraser || activeTool == .instantEraser) ? .anyInput : .pencilOnly
    }

    private func applyToolToAllCanvases() {
        for canvas in canvasViews.values {
            applyTool(to: canvas)
            applyInputPolicy(to: canvas)
        }
    }

    private func scheduleAutoSave(for pageIndex: Int) {
        pendingSaveWorkItems[pageIndex]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingSaveWorkItems[pageIndex] = nil
            self?.persistDrawing(for: pageIndex)
        }

        pendingSaveWorkItems[pageIndex] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func persistDrawing(for pageIndex: Int) {
        guard let canvas = canvasViews[pageIndex],
              let modelContext,
              let libraryItemID else { return }

        let drawing = canvas.drawing

        if drawing.strokes.isEmpty {
            annotationStore.deleteIfEmpty(drawing: drawing, forItem: libraryItemID, pageIndex: pageIndex, context: modelContext)
            return
        }

        annotationStore.save(drawing: drawing, forItem: libraryItemID, pageIndex: pageIndex, context: modelContext)
    }

    private func loadDrawing(for pageIndex: Int) -> PKDrawing? {
        guard let modelContext, let libraryItemID else { return nil }
        return annotationStore.load(forItem: libraryItemID, pageIndex: pageIndex, context: modelContext)
    }

    private func purgeOffscreenCanvases() {
        let offscreen = canvasViews.compactMap { pageIndex, canvas -> Int? in
            let isOffscreen = canvas.window == nil || canvas.superview == nil
            return isOffscreen && canvas.drawing.strokes.isEmpty ? pageIndex : nil
        }

        for pageIndex in offscreen {
            pendingSaveWorkItems[pageIndex]?.cancel()
            pendingSaveWorkItems[pageIndex] = nil
            canvasViews[pageIndex]?.delegate = nil
            canvasViews.removeValue(forKey: pageIndex)
        }
    }
}

// MARK: - ManagedUndoCanvasView

final class ManagedUndoCanvasView: PKCanvasView {
    weak var externalUndoManager: UndoManager?
    var activeTool: AnnotationTool = .pen

    override var undoManager: UndoManager? {
        externalUndoManager ?? super.undoManager
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handleInstantErase(with: touches) {
            return
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handleInstantErase(with: touches) {
            return
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if activeTool == .instantEraser {
            return
        }
        super.touchesEnded(touches, with: event)
    }

    private func handleInstantErase(with touches: Set<UITouch>) -> Bool {
        guard activeTool == .instantEraser else { return false }

        let touchPoints = touches.map { $0.location(in: self) }
        guard !touchPoints.isEmpty else { return true }

        let updatedStrokes = drawing.strokes.filter { stroke in
            !touchPoints.contains { point in
                stroke.renderBounds.insetBy(dx: -12, dy: -12).contains(point)
            }
        }

        if updatedStrokes.count != drawing.strokes.count {
            drawing = PKDrawing(strokes: updatedStrokes)
            delegate?.canvasViewDrawingDidChange?(self)
        }

        return true
    }
}

#else
import SwiftUI
import SwiftData

final class PDFViewCoordinator: NSObject, ObservableObject {
    weak var viewer: PagedImageViewer?
    var onPageChanged: ((Int, Int) -> Void)?
    let canvasManager = CanvasManager()
    let pageCache = PageImageCache()
    var loadedDocumentURL: URL?
    var isAnnotating: Bool = false
    var canvasUndoManager: UndoManager?
    var prefetchedDocumentURL: URL?
    var prefetchedPageCount: Int?

    func configureAnnotationPersistence(modelContext: ModelContext, libraryItemID: UUID) {}
    func saveAnnotationsNow() {}
    func resetForDocument(_ documentURL: URL?) {}
    func setActiveTool(_ tool: Any) {}
    func setColor(_ color: Any) {}
    func setThickness(_ thickness: CGFloat) {}
    func goToNextPage() {}
    func goToPreviousPage() {}
    func goToPage(_ index: Int) {}

    var currentPageIndex: Int { 0 }
    var totalPageCount: Int { 0 }
}

final class CanvasManager: NSObject {
    var isAnnotating = false
    weak var undoManager: UndoManager?
    var modelContext: ModelContext?
    var libraryItemID: UUID?

    func setActiveTool(_ tool: Any) {}
    func setColor(_ color: Any) {}
    func setThickness(_ thickness: CGFloat) {}
    func canvas(for pageIndex: Int) -> Any? { nil }
    func saveCanvas(for pageIndex: Int) {}
    func saveAllCanvasesNow() {}
    func removeAllCanvases() {}
}
#endif
