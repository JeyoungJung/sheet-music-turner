import UIKit

/// Thread-safe cache for pre-rendered PDF page images.
/// Uses NSCache with LRU eviction; renders pages on cache miss via PageImageRenderer.
final class PageImageCache {

    private let cache = NSCache<NSString, UIImage>()
    private let renderer = PageImageRenderer()
    private let renderQueue = DispatchQueue(label: "com.sheetmusicturner.page-cache", qos: .userInitiated, attributes: .concurrent)
    private var pendingRenders: Set<String> = []
    private let pendingLock = NSLock()

    init() {
        cache.countLimit = 16
    }

    // MARK: - Synchronous Lookup

    /// Returns cached image if available, nil otherwise.
    func image(for documentURL: URL, pageIndex: Int) -> UIImage? {
        cache.object(forKey: cacheKey(documentURL: documentURL, pageIndex: pageIndex))
    }

    // MARK: - Async Rendering

    /// Pre-renders specified pages in background. Completion called on main thread when all done.
    func prerender(documentURL: URL, pageIndices: [Int], targetSize: CGSize, completion: (() -> Void)? = nil) {
        let uncached = pageIndices.filter { image(for: documentURL, pageIndex: $0) == nil }
        guard !uncached.isEmpty else {
            completion?()
            return
        }

        let group = DispatchGroup()

        for pageIndex in uncached {
            let key = cacheKeyString(documentURL: documentURL, pageIndex: pageIndex)

            pendingLock.lock()
            let alreadyPending = pendingRenders.contains(key)
            if !alreadyPending {
                pendingRenders.insert(key)
            }
            pendingLock.unlock()

            guard !alreadyPending else { continue }

            group.enter()
            renderQueue.async { [weak self] in
                guard let self else {
                    group.leave()
                    return
                }

                let image = PageImageRenderer.renderPageSync(documentURL: documentURL, pageIndex: pageIndex, targetSize: targetSize)

                self.pendingLock.lock()
                self.pendingRenders.remove(key)
                self.pendingLock.unlock()

                if let image {
                    self.cache.setObject(image, forKey: self.cacheKey(documentURL: documentURL, pageIndex: pageIndex))
                }

                group.leave()
            }
        }

        if let completion {
            group.notify(queue: .main) {
                completion()
            }
        }
    }

    /// Pre-renders all pages for a document.
    func prerenderAll(documentURL: URL, pageCount: Int, targetSize: CGSize, completion: (() -> Void)? = nil) {
        let indices = Array(0..<pageCount)
        prerender(documentURL: documentURL, pageIndices: indices, targetSize: targetSize, completion: completion)
    }

    /// Renders a single page synchronously on the current thread. Use sparingly (e.g., first page on load).
    func renderSync(documentURL: URL, pageIndex: Int, targetSize: CGSize) -> UIImage? {
        if let cached = image(for: documentURL, pageIndex: pageIndex) {
            return cached
        }

        let image = PageImageRenderer.renderPageSync(documentURL: documentURL, pageIndex: pageIndex, targetSize: targetSize)
        if let image {
            cache.setObject(image, forKey: cacheKey(documentURL: documentURL, pageIndex: pageIndex))
        }
        return image
    }

    /// Pre-render adjacent pages around the given index.
    func prerenderAdjacent(documentURL: URL, around pageIndex: Int, pageCount: Int, targetSize: CGSize, radius: Int = 3) {
        let lowerBound = max(0, pageIndex - radius)
        let upperBound = min(pageCount - 1, pageIndex + radius)
        guard lowerBound <= upperBound else { return }
        let indices = Array(lowerBound...upperBound)
        prerender(documentURL: documentURL, pageIndices: indices, targetSize: targetSize)
    }

    /// Clears all cached images.
    func invalidate() {
        cache.removeAllObjects()
        pendingLock.lock()
        pendingRenders.removeAll()
        pendingLock.unlock()
    }

    // MARK: - Private

    private func cacheKey(documentURL: URL, pageIndex: Int) -> NSString {
        cacheKeyString(documentURL: documentURL, pageIndex: pageIndex) as NSString
    }

    private func cacheKeyString(documentURL: URL, pageIndex: Int) -> String {
        "\(documentURL.absoluteString)#\(pageIndex)"
    }
}
