import SwiftUI
import SwiftData
import PDFKit

struct PDFImporter {
    @MainActor
    static func handleImport(
        result: Result<URL, Error>,
        context: ModelContext
    ) -> ImportResult {
        switch result {
        case .failure(let error):
            return .failure("Could not access file: \(error.localizedDescription)")

        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            guard FileStore.isPDF(url: url) || FileStore.isSupportedImage(url: url) else {
                return .failure("This file type is not supported.")
            }

            if FileStore.isPasswordProtected(url: url) {
                return .failure("This PDF is password-protected and cannot be opened.")
            }

            guard let pageCount = FileStore.importedPageCount(for: url), pageCount > 0 else {
                return .failure("Could not read this file. The file may be corrupted.")
            }

            do {
                let fileName = try FileStore.copyImportedScoreToSandbox(from: url)
                let name = url.deletingPathExtension().lastPathComponent
                let item = LibraryItem(name: name, fileName: fileName, pageCount: pageCount)
                context.insert(item)
                return .success(item)
            } catch {
                return .failure("Could not import file: \(error.localizedDescription)")
            }
        }
    }

    enum ImportResult {
        case success(LibraryItem)
        case failure(String)
    }
}
