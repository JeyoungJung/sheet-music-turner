import Foundation
import SwiftData
import PDFKit
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

struct FileStore {

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func pdfURL(for item: LibraryItem) -> URL {
        item.fileURL
    }

    static func copyImportedScoreToSandbox(from sourceURL: URL) throws -> String {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let fileName = uniqueFileName(base: originalName, ext: "pdf")
        let destURL = documentsURL.appendingPathComponent(fileName)

        if isPDF(url: sourceURL) {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return fileName
        }

        try writeImageAsPDF(from: sourceURL, to: destURL)
        return fileName
    }

    static func deleteScore(item: LibraryItem) {
        do {
            try FileManager.default.removeItem(at: pdfURL(for: item))
        } catch {
            print("[FileStore] deleteScore error: \(error)")
        }
    }

    static func importedPageCount(for url: URL) -> Int? {
        if isPDF(url: url) {
            guard let doc = PDFDocument(url: url), doc.pageCount > 0 else { return nil }
            return doc.pageCount
        }

        return isSupportedImage(url: url) ? 1 : nil
    }

    static func isPasswordProtected(url: URL) -> Bool {
        guard isPDF(url: url) else { return false }
        guard let doc = PDFDocument(url: url) else { return false }
        return doc.isEncrypted && doc.isLocked
    }

    static func isPDF(url: URL) -> Bool {
        contentType(for: url)?.conforms(to: .pdf) == true
    }

    static func isSupportedImage(url: URL) -> Bool {
        contentType(for: url)?.conforms(to: .image) == true
    }

    private static func contentType(for url: URL) -> UTType? {
        if let resourceType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return resourceType
        }

        return UTType(filenameExtension: url.pathExtension)
    }

    private static func writeImageAsPDF(from sourceURL: URL, to destinationURL: URL) throws {
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: sourceURL.path),
              let page = PDFPage(image: image) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let document = PDFDocument()
        document.insert(page, at: 0)

        guard document.write(to: destinationURL) else {
            throw CocoaError(.fileWriteUnknown)
        }
        #else
        throw CocoaError(.featureUnsupported)
        #endif
    }

    private static func uniqueFileName(base: String, ext: String) -> String {
        let candidate = "\(base).\(ext)"
        if !FileManager.default.fileExists(atPath: documentsURL.appendingPathComponent(candidate).path) {
            return candidate
        }
        var counter = 1
        while true {
            let name = "\(base)-\(counter).\(ext)"
            if !FileManager.default.fileExists(atPath: documentsURL.appendingPathComponent(name).path) {
                return name
            }
            counter += 1
        }
    }
}
