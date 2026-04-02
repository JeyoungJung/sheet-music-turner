import UIKit
import PencilKit

/// Displays a single PDF page as a UIImage with an optional PKCanvasView overlay for annotations.
///
/// The canvas always uses a **canonical coordinate system** based on the screen-size display rect.
/// When the container changes (e.g., normal → fullscreen), only the canvas transform changes —
/// the canvas bounds and drawing coordinates stay fixed, so strokes don't shift.
final class ImagePageView: UIView {

    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .white
        iv.clipsToBounds = true
        return iv
    }()

    private(set) var canvasView: ManagedUndoCanvasView?

    /// The canonical canvas size — set once based on the image at screen-bounds scale.
    /// This stays constant regardless of container size changes.
    private var canonicalCanvasSize: CGSize = .zero

    var pageImage: UIImage? {
        didSet {
            imageView.image = pageImage
            updateCanonicalCanvasSize()
            setNeedsLayout()
        }
    }

    var isAnnotating: Bool = false {
        didSet {
            guard oldValue != isAnnotating else { return }
            updateCanvasInteraction()
        }
    }

    var activeTool: AnnotationTool = .pen {
        didSet {
            guard oldValue != activeTool else { return }
            if let canvas = canvasView {
                applyToolToCanvas(canvas)
            }
        }
    }

    var activeColor: AnnotationColorValue = .black
    var activeThickness: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        layoutCanvas()
    }

    // MARK: - Canvas Management

    /// Attaches a canvas view for annotation on this page.
    func attachCanvas(_ canvas: ManagedUndoCanvasView) {
        if canvasView !== canvas {
            canvasView?.removeFromSuperview()
            canvasView = canvas
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            addSubview(canvas)
            layoutCanvas()
        }
        applyToolToCanvas(canvas)
        updateCanvasInteraction()
    }

    /// Removes the canvas view.
    func detachCanvas() {
        canvasView?.removeFromSuperview()
        canvasView = nil
    }

    // MARK: - Private

    /// Computes the canonical canvas size from the image, based on screen-bounds display.
    /// This is the "reference" size used for the canvas bounds so that drawing coordinates
    /// stay fixed regardless of container size changes.
    private func updateCanonicalCanvasSize() {
        guard let image = pageImage else {
            canonicalCanvasSize = .zero
            return
        }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            canonicalCanvasSize = .zero
            return
        }

        // Use screen bounds as the canonical reference container
        let screenSize = UIScreen.main.bounds.size
        let scaleW = screenSize.width / imageSize.width
        let scaleH = screenSize.height / imageSize.height
        let scale = min(scaleW, scaleH)

        canonicalCanvasSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func layoutCanvas() {
        guard let canvas = canvasView else { return }

        let displayRect = imageDisplayRect()

        guard canonicalCanvasSize.width > 0, canonicalCanvasSize.height > 0,
              displayRect.width > 0, displayRect.height > 0 else {
            canvas.frame = displayRect
            canvas.transform = .identity
            return
        }

        // Reset transform before setting frame/bounds
        canvas.transform = .identity

        // Set bounds to canonical size — this is the coordinate space for strokes
        canvas.bounds = CGRect(origin: .zero, size: canonicalCanvasSize)

        // Compute scale from canonical → current display
        let scaleX = displayRect.width / canonicalCanvasSize.width
        let scaleY = displayRect.height / canonicalCanvasSize.height

        // Position center at the center of the display rect
        canvas.center = CGPoint(
            x: displayRect.midX,
            y: displayRect.midY
        )

        // Apply scale transform
        canvas.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
    }

    /// Calculates the actual display rect of the image within the imageView (accounting for aspectFit).
    func imageDisplayRect() -> CGRect {
        guard let image = pageImage else { return bounds }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }

        let viewSize = bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return bounds }

        let scaleW = viewSize.width / imageSize.width
        let scaleH = viewSize.height / imageSize.height
        let scale = min(scaleW, scaleH)

        let displayWidth = imageSize.width * scale
        let displayHeight = imageSize.height * scale

        let x = (viewSize.width - displayWidth) / 2
        let y = (viewSize.height - displayHeight) / 2

        return CGRect(x: x, y: y, width: displayWidth, height: displayHeight)
    }

    private func updateCanvasInteraction() {
        guard let canvas = canvasView else { return }
        canvas.isUserInteractionEnabled = isAnnotating
        if isAnnotating {
            canvas.drawingPolicy = (activeTool == .eraser || activeTool == .instantEraser) ? .anyInput : .pencilOnly
        } else {
            canvas.drawingPolicy = .pencilOnly
        }
    }

    private func applyToolToCanvas(_ canvas: ManagedUndoCanvasView) {
        canvas.activeTool = activeTool

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

        canvas.drawingPolicy = (activeTool == .eraser || activeTool == .instantEraser) ? .anyInput : .pencilOnly
    }
}
