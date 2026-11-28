import SwiftData
import SwiftUI
import UIKit

/// Selection, persistence, and viewport camera helpers for `StickerBoardView`.
extension StickerBoardView {
    func selectSticker(_ record: StickerRecord) {
        if selectedStickerID == record.id {
            return
        }
        commitDraftIfNeeded()
        resetTransientGestureState()
        selectedStickerID = record.id
        if let placement = placementByStickerID[record.id] {
            draftStickerID = record.id
            draftTransform = DraftStickerTransform(placement: placement)
        } else {
            draftStickerID = nil
            draftTransform = nil
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func syncDraftForCurrentSelection() {
        guard let selectedStickerID,
              let placement = placementByStickerID[selectedStickerID]
        else {
            draftStickerID = nil
            draftTransform = nil
            return
        }
        if draftTransform == nil || draftStickerID != selectedStickerID {
            draftStickerID = selectedStickerID
            draftTransform = DraftStickerTransform(placement: placement)
        }
    }

    func commitDraftIfNeeded() {
        guard let selectedID = selectedStickerID,
              draftStickerID == selectedID,
              let draft = draftTransform,
              let placement = placementByStickerID[selectedID]
        else { return }
        placement.x = draft.x
        placement.y = draft.y
        placement.scale = draft.scale
        placement.rotation = draft.rotation
        placement.updatedAt = Date()
        try? modelContext.save()
    }

    func commitDraftAndDeselect(haptic: Bool = false) {
        guard selectedStickerID != nil else { return }
        commitDraftIfNeeded()
        selectedStickerID = nil
        draftStickerID = nil
        draftTransform = nil
        resetTransientGestureState()
        if haptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    func resetTransientGestureState() {
        dragStartWorld = nil
        isDraggingSticker = false
        isTwoFingerTransforming = false
        pinchBaseScale = nil
        rotateBaseRadians = nil
        isSnappedUpright = false
    }

    func pinToFront(_ record: StickerRecord) {
        guard let placement = placementByStickerID[record.id] else { return }
        let maxOtherZ = placements
            .filter { $0.stickerID != record.id }
            .map(\.zIndex)
            .max()
        if let maxOtherZ, placement.zIndex <= maxOtherZ {
            let nextZ = maxOtherZ + 1
            placement.zIndex = nextZ
            record.zIndex = nextZ
            placement.updatedAt = Date()
            try? modelContext.save()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func deleteSticker(_ record: StickerRecord) {
        if selectedStickerID == record.id {
            selectedStickerID = nil
            draftStickerID = nil
            draftTransform = nil
            resetTransientGestureState()
        }
        try? StickerStorage.delete(record, in: modelContext)
        onStickersMutated()
    }

    func initializeViewportIfNeeded(size: CGSize) {
        guard !didInitializeViewport, size.width > 1, size.height > 1 else { return }
        didInitializeViewport = true

        if let focusID = initialFocusStickerID,
           let placement = placementByStickerID[focusID] {
            viewport = BoardCanvasMath.focus(
                on: CGPoint(x: placement.x, y: placement.y),
                zoom: 1.0
            )
            selectedStickerID = focusID
            draftStickerID = focusID
            draftTransform = DraftStickerTransform(placement: placement)
            reportViewportCenter()
            return
        }

        if let saved = StickerStorage.loadBoardViewport(in: modelContext) {
            viewport = saved
            reportViewportCenter()
            return
        }

        fitAllStickers(in: size, animated: false)
    }

    func fitAllStickers(in size: CGSize, animated: Bool) {
        let geometries = orderedItems.map { record, placement in
            BoardItemGeometry(
                x: placement.x,
                y: placement.y,
                scale: placement.scale,
                aspectRatio: record.aspectRatio
            )
        }
        let target = BoardCanvasMath.fitAll(items: geometries, viewportSize: size)
        applyViewport(target, animated: animated)
    }

    func resetZoomTo100(in size: CGSize) {
        let geometries = orderedItems.map { record, placement in
            BoardItemGeometry(
                x: placement.x,
                y: placement.y,
                scale: placement.scale,
                aspectRatio: record.aspectRatio
            )
        }
        let fit = BoardCanvasMath.fitAll(items: geometries, viewportSize: size)
        let contentCenter = BoardCanvasMath.visibleWorldCenter(viewport: fit)
        applyViewport(BoardCanvasMath.focus(on: contentCenter, zoom: 1.0), animated: true)
    }

    func toggleFitOrReset(in size: CGSize) {
        if abs(viewport.zoom - 1.0) < 0.08 {
            fitAllStickers(in: size, animated: true)
        } else {
            resetZoomTo100(in: size)
        }
    }

    func applyViewport(_ target: BoardViewport, animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                viewport = target
            }
        } else {
            viewport = target
        }
        reportViewportCenter()
        StickerStorage.saveBoardViewport(target, in: modelContext)
    }

    func reportViewportCenter() {
        onViewportCenterChanged(BoardCanvasMath.visibleWorldCenter(viewport: viewport))
    }
}
