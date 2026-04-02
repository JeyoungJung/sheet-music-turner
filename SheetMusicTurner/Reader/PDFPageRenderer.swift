import UIKit
import CoreGraphics

/// Renders individual PDF pages to UIImage using CGPDFDocument.
/// Bypasses PDFView entirely for zero-latency page display.
final class PageImageRenderer {

    private let renderQueue = DispatchQueue(label: "com.sheetmusicturner.page-render", qos: .userInitiated, attributes: .concurrent)

    /// Render a single PDF page to UIImage at the given target size.
    /// The page is scaled to fit within targetSize maintaining aspect ratio (height-fit).
    func renderPage(
        documentURL: URL,
        pageIndex: Int,
        targetSize: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        renderQueue.async {
            let image = Self.renderPageSync(documentURL: documentURL, pageIndex: pageIndex, targetSize: targetSize)
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    /// Synchronous page render — call from background thread only.
    static func renderPageSync(
        documentURL: URL,
        pageIndex: Int,
        targetSize: CGSize
    ) -> UIImage? {
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        guard let cgDocument = CGPDFDocument(documentURL as CFURL) else { return nil }
        // CGPDFDocument pages are 1-indexed
        guard let cgPage = cgDocument.page(at: pageIndex + 1) else { return nil }

        let pageRect = pageRect(for: cgPage)
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }

        // Height-fit: scale so page height matches target height
        let scaleH = targetSize.height / pageRect.height
        let scaleW = targetSize.width / pageRect.width
        let scale = min(scaleW, scaleH)

        let renderWidth = max(1, floor(pageRect.width * scale))
        let renderHeight = max(1, floor(pageRect.height * scale))
        let renderSize = CGSize(width: renderWidth, height: renderHeight)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale  // 2x on iPad Pro Retina
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            let cgContext = context.cgContext
            cgContext.saveGState()
            // PDF coordinate system: origin at bottom-left, Y increases upward.
            // UIKit: origin at top-left, Y increases downward.
            // Flip vertically and scale.
            cgContext.translateBy(x: 0, y: renderHeight)
            cgContext.scaleBy(x: scale, y: -scale)
            cgContext.drawPDFPage(cgPage)
            cgContext.restoreGState()
        }

        return image
    }

    /// Get the effective page rect using cropBox (falling back to mediaBox).
    private static func pageRect(for page: CGPDFPage) -> CGRect {
        let cropBox = page.getBoxRect(.cropBox)
        if !cropBox.isEmpty {
            return cropBox
        }
        return page.getBoxRect(.mediaBox)
    }
}
