import Foundation
import SwiftData

/// Persisted viewport state for a freeform sticker board (pan offset + zoom).
/// Stored separately from sticker records so board layout is decoupled from the library.
@Model
final class BoardLayoutRecord {
    var boardID: String = StickerRecord.defaultBoardID
    var offsetX: Double = 0
    var offsetY: Double = 0
    var zoomScale: Double = 1.0
    var hasSavedViewport: Bool = false
    var updatedAt: Date = Date()

    init(
        boardID: String = StickerRecord.defaultBoardID,
        offsetX: Double = 0,
        offsetY: Double = 0,
        zoomScale: Double = 1.0,
        hasSavedViewport: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.boardID = boardID
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.zoomScale = zoomScale
        self.hasSavedViewport = hasSavedViewport
        self.updatedAt = updatedAt
    }
}

/// Decoupled placement of a sticker on a specific freeform board in world coordinates.
/// World origin `(0, 0)` represents the center of the board canvas.
@Model
final class BoardItemPlacement {
    var id: UUID = UUID()
    var boardID: String = StickerRecord.defaultBoardID
    var stickerID: UUID = UUID()

    /// Center X in board world points (0 is canvas center).
    var x: Double = 0
    /// Center Y in board world points (0 is canvas center).
    var y: Double = 0
    /// Visual scale relative to `BoardCanvasMath.baseStickerLongSide`.
    var scale: Double = 1.0
    /// Rotation angle in radians.
    var rotation: Double = 0.0
    /// Stacking order on the board; higher sits on top.
    var zIndex: Int = 0
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        boardID: String = StickerRecord.defaultBoardID,
        stickerID: UUID,
        x: Double = 0,
        y: Double = 0,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        zIndex: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.boardID = boardID
        self.stickerID = stickerID
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.zIndex = zIndex
        self.updatedAt = updatedAt
    }
}
