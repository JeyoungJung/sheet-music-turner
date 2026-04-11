import UIKit
import PencilKit

/// Custom page viewer that displays pre-rendered PDF page images for instant page turns.
/// Replaces PDFView entirely — no PDFKit dependency for visible rendering.
final class PagedImageViewer: UIViewController, UIScrollViewDelegate {

    // MARK: - Public Properties

    var documentURL: URL? {
        didSet {
            guard oldValue != documentURL else { return }
            reloadDocument()
        }
    }

    private(set) var pageCount: Int = 0
    private(set) var currentPageIndex: Int = 0

    var isFullscreen: Bool = false {
        didSet {
            guard oldValue != isFullscreen else { return }
            updateScrollBehavior()
            view.setNeedsLayout()
        }
    }

    var isAnnotating: Bool = false {
        didSet {
            guard oldValue != isAnnotating else { return }
            pageView.isAnnotating = isAnnotating
            updateScrollBehavior()
        }
    }

    var activeTool: AnnotationTool = .pen {
        didSet {
            pageView.activeTool = activeTool
        }
    }

    var activeColor: AnnotationColorValue = AnnotationColorValue(red: 0, green: 0, blue: 0, alpha: 1) {
        didSet {
            pageView.activeColor = activeColor
        }
    }

    var activeThickness: CGFloat = 1 {
        didSet {
            pageView.activeThickness = activeThickness
        }
    }

    /// Extra bottom inset when annotation toolbar is visible, so the user can
    /// scroll the page up to reach content behind the toolbar.
    var annotationBottomInset: CGFloat = 0 {
        didSet {
            guard oldValue != annotationBottomInset else { return }
            updateContentInset()
        }
    }

    /// Called with zone index: 0 = left, 1 = center, 2 = right.
    var onTapZone: ((Int) -> Void)?

    /// Called with (pageIndex, totalPages) when page changes.
    var onPageChanged: ((Int, Int) -> Void)?

    /// Called when a canvas is needed for a page index. Returns the canvas to attach.
    var canvasProvider: ((Int) -> ManagedUndoCanvasView?)?

    /// Called when the displayed page's canvas should be saved.
    var onCanvasWillDetach: ((Int) -> Void)?

    let pageCache: PageImageCache

    // MARK: - Private

    private let zoomScrollView = UIScrollView()
    private let pageView = ImagePageView()
    private var tapRecognizer: UITapGestureRecognizer?
    private var lastLayoutSize: CGSize = .zero
    private var sceneActivationObserver: NSObjectProtocol?

    // MARK: - Init

    init(pageCache: PageImageCache) {
        self.pageCache = pageCache
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    deinit {
        if let sceneActivationObserver {
            NotificationCenter.default.removeObserver(sceneActivationObserver)
        }
    }

    // MARK: - Lifecycle

    override func loadView() {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = false
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Zoom scroll view wraps the page view for annotation pinch-zoom.
        zoomScrollView.delegate = self
        zoomScrollView.showsVerticalScrollIndicator = false
        zoomScrollView.showsHorizontalScrollIndicator = false
        zoomScrollView.contentInsetAdjustmentBehavior = .never
        zoomScrollView.bounces = false
        zoomScrollView.bouncesZoom = false
        view.addSubview(zoomScrollView)

        zoomScrollView.addSubview(pageView)

        // Tap recognizer — finger only
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesEnded = false
        tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        view.addGestureRecognizer(tap)
        tapRecognizer = tap

        updateScrollBehavior()

        sceneActivationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetZoomToIdentity()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let targetFrame: CGRect
        if isFullscreen {
            let windowBounds = view.window?.bounds ?? UIScreen.main.bounds
            let originInView = view.convert(windowBounds.origin, from: view.window)
            targetFrame = CGRect(origin: originInView, size: windowBounds.size)
        } else {
            targetFrame = view.bounds
        }

        let sizeChanged = targetFrame.size != lastLayoutSize
        lastLayoutSize = targetFrame.size

        zoomScrollView.frame = targetFrame
        pageView.frame = CGRect(origin: .zero, size: targetFrame.size)
        zoomScrollView.contentSize = targetFrame.size

        if sizeChanged {
            zoomScrollView.zoomScale = 1
            zoomScrollView.contentOffset = .zero
            zoomScrollView.minimumZoomScale = 1
            zoomScrollView.maximumZoomScale = isAnnotating ? 4 : 1
        }
    }

    /// Prevent PDFView from claiming keyboard first responder.
    override var canBecomeFirstResponder: Bool { false }

    // MARK: - Page Navigation

    func goToPage(_ index: Int) {
        guard index >= 0, index < pageCount else { return }

        let previousIndex = currentPageIndex

        // Save current canvas before switching
        if previousIndex != index {
            onCanvasWillDetach?(previousIndex)
            pageView.detachCanvas()
        }

        currentPageIndex = index

        // Show cached image instantly
        if let documentURL {
            let targetSize = pageViewSize()
            if let cachedImage = pageCache.image(for: documentURL, pageIndex: index) {
                pageView.pageImage = cachedImage
            } else {
                // Synchronous render as fallback (should be rare after prerender)
                let image = pageCache.renderSync(documentURL: documentURL, pageIndex: index, targetSize: targetSize)
                pageView.pageImage = image
            }

            // Pre-render adjacent pages
            pageCache.prerenderAdjacent(documentURL: documentURL, around: index, pageCount: pageCount, targetSize: targetSize)
        }

        // Attach canvas for the new page
        if let canvas = canvasProvider?(index) {
            pageView.attachCanvas(canvas)
        }

        // Reset zoom on page change
        if zoomScrollView.zoomScale != 1 {
            zoomScrollView.zoomScale = 1
        }

        onPageChanged?(index, pageCount)
    }

    func goToNextPage() {
        let nextIndex = currentPageIndex + 1
        guard nextIndex < pageCount else { return }
        goToPage(nextIndex)
    }

    func goToPreviousPage() {
        let prevIndex = currentPageIndex - 1
        guard prevIndex >= 0 else { return }
        goToPage(prevIndex)
    }

    // MARK: - Document Loading

    func loadDocument(url: URL, pageCount: Int) {
        self.documentURL = url
        self.pageCount = pageCount
        self.currentPageIndex = 0

        let targetSize = pageViewSize()

        // Render first page synchronously for instant display
        let firstImage = pageCache.renderSync(documentURL: url, pageIndex: 0, targetSize: targetSize)
        pageView.pageImage = firstImage

        // Attach canvas for page 0
        if let canvas = canvasProvider?(0) {
            pageView.attachCanvas(canvas)
        }

        // Pre-render all pages in background
        pageCache.prerenderAll(documentURL: url, pageCount: pageCount, targetSize: targetSize)

        onPageChanged?(0, pageCount)
    }

    // MARK: - UIScrollViewDelegate (Zoom)

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        isAnnotating ? pageView : nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Center the page view when zoomed smaller than scroll view
        let boundsSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize

        let offsetX = max(0, (boundsSize.width - contentSize.width) / 2)
        let offsetY = max(0, (boundsSize.height - contentSize.height) / 2)

        pageView.center = CGPoint(
            x: contentSize.width / 2 + offsetX,
            y: contentSize.height / 2 + offsetY
        )
    }

    // MARK: - Private

    private func reloadDocument() {
        pageCount = 0
        currentPageIndex = 0
        pageView.pageImage = nil
        pageView.detachCanvas()
    }

    private func resetZoomToIdentity() {
        lastLayoutSize = .zero
        zoomScrollView.zoomScale = 1
        zoomScrollView.contentOffset = .zero
        zoomScrollView.minimumZoomScale = 1
        zoomScrollView.maximumZoomScale = isAnnotating ? 4 : 1
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func pageViewSize() -> CGSize {
        // Always render at screen bounds so the image (and canvas coordinate space)
        // stays consistent regardless of fullscreen vs normal mode.
        UIScreen.main.bounds.size
    }

    @objc private func handleTap(_ rec: UITapGestureRecognizer) {
        guard rec.state == .ended, let zone = onTapZone else { return }
        let x = rec.location(in: view).x
        let w = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        if x < w * 0.30 {
            zone(0) // left
        } else if x > w * 0.70 {
            zone(2) // right
        } else {
            zone(1) // center
        }
    }

    private func updateScrollBehavior() {
        zoomScrollView.zoomScale = 1
        zoomScrollView.contentOffset = .zero
        pageView.frame = CGRect(origin: .zero, size: zoomScrollView.bounds.size)
        zoomScrollView.contentSize = zoomScrollView.bounds.size

        if isAnnotating {
            zoomScrollView.minimumZoomScale = 1
            zoomScrollView.maximumZoomScale = 4
            zoomScrollView.isScrollEnabled = true
            zoomScrollView.bounces = true
            zoomScrollView.panGestureRecognizer.minimumNumberOfTouches = 2

            let directTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            for recognizer in zoomScrollView.gestureRecognizers ?? [] {
                recognizer.allowedTouchTypes = directTouchTypes
            }
        } else {
            zoomScrollView.minimumZoomScale = 1
            zoomScrollView.maximumZoomScale = 1
            zoomScrollView.isScrollEnabled = false
            zoomScrollView.bounces = false
        }

        updateContentInset()

        for recognizer in zoomScrollView.gestureRecognizers ?? [] {
            if let tapRecognizer = recognizer as? UITapGestureRecognizer,
               tapRecognizer.numberOfTapsRequired > 1 {
                tapRecognizer.isEnabled = false
            }
        }
    }

    private func updateContentInset() {
        let bottomInset = isAnnotating ? annotationBottomInset : 0
        zoomScrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
    }
}
