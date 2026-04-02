import Foundation
import PencilKit
import SwiftData

final class AnnotationStore {
    func save(drawing: PKDrawing, forItem itemID: UUID, pageIndex: Int, context: ModelContext) {
        guard !drawing.strokes.isEmpty else {
            deleteIfEmpty(drawing: drawing, forItem: itemID, pageIndex: pageIndex, context: context)
            return
        }

        let drawingData = drawing.dataRepresentation()

        if let existingDrawing = fetchPageDrawing(forItem: itemID, pageIndex: pageIndex, context: context) {
            existingDrawing.drawingData = drawingData
            existingDrawing.lastModified = Date()
        } else {
            context.insert(PageDrawing(libraryItemID: itemID, pageIndex: pageIndex, drawingData: drawingData))
        }

        do {
            try context.save()
        } catch {
            print("[AnnotationStore] save error: \(error)")
        }
    }

    func load(forItem itemID: UUID, pageIndex: Int, context: ModelContext) -> PKDrawing? {
        guard let pageDrawing = fetchPageDrawing(forItem: itemID, pageIndex: pageIndex, context: context) else {
            return nil
        }

        do {
            return try PKDrawing(data: pageDrawing.drawingData)
        } catch {
            print("[AnnotationStore] drawing decode error: \(error)")
            return PKDrawing()
        }
    }

    func deleteIfEmpty(drawing: PKDrawing, forItem itemID: UUID, pageIndex: Int, context: ModelContext) {
        guard drawing.strokes.isEmpty,
              let existingDrawing = fetchPageDrawing(forItem: itemID, pageIndex: pageIndex, context: context) else {
            return
        }

        context.delete(existingDrawing)
        do {
            try context.save()
        } catch {
            print("[AnnotationStore] delete save error: \(error)")
        }
    }

    private func fetchPageDrawing(forItem itemID: UUID, pageIndex: Int, context: ModelContext) -> PageDrawing? {
        let targetItemID = itemID
        let targetPageIndex = pageIndex
        let descriptor = FetchDescriptor<PageDrawing>(
            predicate: #Predicate<PageDrawing> {
                $0.libraryItemID == targetItemID && $0.pageIndex == targetPageIndex
            }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("[AnnotationStore] fetch error: \(error)")
            return nil
        }
    }
}
