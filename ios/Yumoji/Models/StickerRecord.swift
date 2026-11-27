import Foundation
import SwiftData

/// Persistent sticker record placed on the freeform board.
/// All fields have defaults or are optional so the schema is CloudKit-ready.
@Model
final class StickerRecord {
    var id: UUID = UUID()
    var boardID: String = StickerRecord.defaultBoardID
    var createdAt: Date = Date()
    var capturedAt: Date?

    /// Normalized horizontal position on the board (0...1).
    var x: Double = 0.5
    /// Vertical center position on the board in points from the top.
    var y: Double = 220
    /// Visual scale factor relative to the base sticker size.
    var scale: Double = 1.0
    /// Rotation angle in radians.
    var rotation: Double = 0.0
    /// Stacking order on the board; higher values sit on top.
    var zIndex: Int = 0

    /// Saved full-resolution PNG pixel dimensions.
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0
    /// Combined byte size of the saved PNG and thumbnail for quick accounting.
    var byteSize: Int64 = 0

    /// Optional metadata reserved for future organization and AI tagging.
    var title: String?
    var note: String?
    var tagsText: String?
    var isFavorite: Bool = false

    /// Lightweight PNG thumbnail (~320px long side) rendered on the board.
    @Attribute(.externalStorage)
    var thumbnailData: Data?

    /// Full-resolution transparent sticker PNG (~1024px long side), loaded on demand.
    @Relationship(deleteRule: .cascade, inverse: \StickerAsset.sticker)
    var asset: StickerAsset?

    static let defaultBoardID = "default"

    init(
        id: UUID = UUID(),
        boardID: String = StickerRecord.defaultBoardID,
        createdAt: Date = Date(),
        capturedAt: Date? = nil,
        x: Double = 0.5,
        y: Double = 220,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        zIndex: Int = 0,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        byteSize: Int64 = 0,
        title: String? = nil,
        note: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false,
        thumbnailData: Data? = nil,
        asset: StickerAsset? = nil
    ) {
        self.id = id
        self.boardID = boardID
        self.createdAt = createdAt
        self.capturedAt = capturedAt
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.zIndex = zIndex
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteSize = byteSize
        self.title = title
        self.note = note
        self.tagsText = Self.encodeTags(tags)
        self.isFavorite = isFavorite
        self.thumbnailData = thumbnailData
        self.asset = asset
    }

    var tags: [String] {
        get { Self.decodeTags(tagsText) }
        set { tagsText = Self.encodeTags(newValue) }
    }

    var aspectRatio: Double {
        guard pixelWidth > 0, pixelHeight > 0 else { return 1.0 }
        return Double(pixelWidth) / Double(pixelHeight)
    }

    static func encodeTags(_ tags: [String]) -> String? {
        let cleaned = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? nil : cleaned.joined(separator: ",")
    }

    static func decodeTags(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// Separate binary payload for the full-size transparent sticker PNG so board queries
/// do not fault full-resolution images into memory until export or inspection.
@Model
final class StickerAsset {
    var id: UUID = UUID()

    @Attribute(.externalStorage)
    var pngData: Data?

    var sticker: StickerRecord?

    init(id: UUID = UUID(), pngData: Data? = nil, sticker: StickerRecord? = nil) {
        self.id = id
        self.pngData = pngData
        self.sticker = sticker
    }
}
