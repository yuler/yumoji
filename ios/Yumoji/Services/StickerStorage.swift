import CoreGraphics
import Foundation
import SwiftData

struct StickerStorageStats: Equatable, Sendable {
    let count: Int
    let totalBytes: Int64

    static let empty = StickerStorageStats(count: 0, totalBytes: 0)
}

struct StickerPlacement: Equatable, Sendable {
    let x: Double
    let y: Double
    let rotation: Double
    let zIndex: Int
}

enum StickerStorageError: Error {
    case encodingFailed
}

/// Manages the local SwiftData store (SQLite + external binary assets),
/// decoupled board layout persistence, and storage stats.
enum StickerStorage {
    static let schema = Schema([
        StickerRecord.self,
        StickerAsset.self,
        BoardLayoutRecord.self,
        BoardItemPlacement.self
    ])

    /// Dedicated subfolder under Application Support so disk usage reflects only sticker storage.
    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("YumojiStickers", isDirectory: true)
    }

    static func storeURL(in directory: URL = defaultDirectory) -> URL {
        directory.appendingPathComponent("YumojiStickers.store")
    }

    static func makeContainer(inMemory: Bool = false, directory: URL? = nil) throws -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(
                "YumojiStickersMemory",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])
        }

        let targetDir = directory ?? defaultDirectory
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let config = ModelConfiguration(
            "YumojiStickers",
            schema: schema,
            url: storeURL(in: targetDir),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Legacy placement helper preserved for compatibility with existing callers/tests.
    static func nextPlacement(existingCount: Int, maxZIndex: Int, preferredY: Double) -> StickerPlacement {
        let xOffsets: [Double] = [0.0, -0.14, 0.14, -0.09, 0.11, -0.16, 0.08]
        let yOffsets: [Double] = [0.0, 26.0, -20.0, 44.0, -34.0, 16.0, 52.0]
        let angles: [Double] = [-0.07, 0.09, -0.11, 0.06, -0.05, 0.12, -0.08]

        let slot = existingCount % xOffsets.count
        let clampedX = min(0.84, max(0.16, 0.5 + xOffsets[slot]))
        let clampedY = max(130.0, preferredY + yOffsets[slot])
        return StickerPlacement(
            x: clampedX,
            y: clampedY,
            rotation: angles[slot],
            zIndex: maxZIndex + 1
        )
    }

    /// Saves a sticker to the library AND creates a decoupled placement on the default board.
    @MainActor
    static func saveSticker(
        _ image: CGImage,
        capturedAt: Date?,
        preferredAnchor: CGPoint? = nil,
        boardID: String = StickerRecord.defaultBoardID,
        in context: ModelContext
    ) throws -> StickerRecord {
        guard let prepared = StickerImageSizer.prepareForStorage(image) else {
            throw StickerStorageError.encodingFailed
        }

        let existingRecords = (try? context.fetch(FetchDescriptor<StickerRecord>())) ?? []
        let existingPlacements = fetchPlacements(boardID: boardID, in: context)
        let maxZ = max(
            existingRecords.map(\.zIndex).max() ?? 0,
            existingPlacements.map(\.zIndex).max() ?? 0
        )

        let anchor = preferredAnchor ?? defaultAnchor(boardID: boardID, existingPlacements: existingPlacements, in: context)
        let worldPlacement = BoardCanvasMath.nextWorldPlacement(
            existingCount: existingPlacements.count,
            maxZIndex: maxZ,
            around: anchor
        )

        let asset = StickerAsset(pngData: prepared.pngData)
        let record = StickerRecord(
            boardID: boardID,
            capturedAt: capturedAt,
            x: 0.5,
            y: 260,
            scale: 1.0,
            rotation: worldPlacement.rotation,
            zIndex: worldPlacement.zIndex,
            pixelWidth: prepared.pixelWidth,
            pixelHeight: prepared.pixelHeight,
            byteSize: prepared.byteSize,
            thumbnailData: prepared.thumbnailData,
            asset: asset
        )
        asset.sticker = record
        context.insert(record)

        let placement = BoardItemPlacement(
            boardID: boardID,
            stickerID: record.id,
            x: worldPlacement.x,
            y: worldPlacement.y,
            scale: 1.0,
            rotation: worldPlacement.rotation,
            zIndex: worldPlacement.zIndex
        )
        context.insert(placement)
        try context.save()
        return record
    }

    /// Convenience overload matching previous API signature.
    @MainActor
    static func saveSticker(
        _ image: CGImage,
        capturedAt: Date?,
        preferredY: Double,
        in context: ModelContext
    ) throws -> StickerRecord {
        let anchor = BoardCanvasMath.migrateLegacyCoordinate(normalizedX: 0.5, legacyY: preferredY)
        return try saveSticker(image, capturedAt: capturedAt, preferredAnchor: anchor, in: context)
    }

    /// Ensures every persisted `StickerRecord` has a corresponding `BoardItemPlacement`,
    /// seamlessly migrating coordinates from earlier builds.
    @MainActor
    @discardableResult
    static func ensureBoardPlacements(
        for records: [StickerRecord],
        boardID: String = StickerRecord.defaultBoardID,
        in context: ModelContext
    ) -> [BoardItemPlacement] {
        var existing = fetchPlacements(boardID: boardID, in: context)
        let existingByStickerID = Dictionary(uniqueKeysWithValues: existing.map { ($0.stickerID, $0) })
        var didInsert = false

        for record in records where existingByStickerID[record.id] == nil {
            let migrated = BoardCanvasMath.migrateLegacyCoordinate(
                normalizedX: record.x,
                legacyY: record.y
            )
            let placement = BoardItemPlacement(
                boardID: boardID,
                stickerID: record.id,
                x: Double(migrated.x),
                y: Double(migrated.y),
                scale: BoardCanvasMath.clampStickerScale(record.scale),
                rotation: record.rotation,
                zIndex: record.zIndex
            )
            context.insert(placement)
            existing.append(placement)
            didInsert = true
        }

        // Remove orphaned placements whose sticker no longer exists.
        let validIDs = Set(records.map(\.id))
        var didDelete = false
        for placement in existing where !validIDs.contains(placement.stickerID) {
            context.delete(placement)
            didDelete = true
        }

        if didInsert || didDelete {
            try? context.save()
            existing = fetchPlacements(boardID: boardID, in: context)
        }
        return existing
    }

    @MainActor
    static func fetchStickerCount(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<StickerRecord>())) ?? 0
    }

    @MainActor
    static func fetchStickerPage(
        offset: Int,
        limit: Int,
        in context: ModelContext
    ) -> [StickerRecord] {
        guard limit > 0 else { return [] }
        var descriptor = FetchDescriptor<StickerRecord>(
            sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.id, order: .reverse)
            ]
        )
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    @discardableResult
    static func ensureAllBoardPlacements(
        boardID: String = StickerRecord.defaultBoardID,
        in context: ModelContext
    ) -> [BoardItemPlacement] {
        let records = (try? context.fetch(FetchDescriptor<StickerRecord>())) ?? []
        return ensureBoardPlacements(for: records, boardID: boardID, in: context)
    }

    @MainActor
    static func fetchPlacements(
        boardID: String = StickerRecord.defaultBoardID,
        in context: ModelContext
    ) -> [BoardItemPlacement] {
        let all = (try? context.fetch(FetchDescriptor<BoardItemPlacement>())) ?? []
        return all.filter { $0.boardID == boardID }
    }

    @MainActor
    static func loadBoardViewport(
        boardID: String = StickerRecord.defaultBoardID,
        in context: ModelContext
    ) -> BoardViewport? {
        guard let record = fetchLayoutRecord(boardID: boardID, in: context),
              record.hasSavedViewport
        else {
            return nil
        }
        return BoardViewport(
            offset: CGSize(width: record.offsetX, height: record.offsetY),
            zoom: BoardCanvasMath.clampCanvasZoom(CGFloat(record.zoomScale))
        )
    }

    @MainActor
    static func saveBoardViewport(
        _ viewport: BoardViewport,
        boardID: String = StickerRecord.defaultBoardID,
        in context: ModelContext
    ) {
        let record = fetchLayoutRecord(boardID: boardID, in: context) ?? {
            let created = BoardLayoutRecord(boardID: boardID)
            context.insert(created)
            return created
        }()
        record.offsetX = Double(viewport.offset.width)
        record.offsetY = Double(viewport.offset.height)
        record.zoomScale = Double(BoardCanvasMath.clampCanvasZoom(viewport.zoom))
        record.hasSavedViewport = true
        record.updatedAt = Date()
        try? context.save()
    }

    @MainActor
    private static func fetchLayoutRecord(
        boardID: String,
        in context: ModelContext
    ) -> BoardLayoutRecord? {
        let all = (try? context.fetch(FetchDescriptor<BoardLayoutRecord>())) ?? []
        return all.first { $0.boardID == boardID }
    }

    @MainActor
    private static func defaultAnchor(
        boardID: String,
        existingPlacements: [BoardItemPlacement],
        in context: ModelContext
    ) -> CGPoint {
        if let savedViewport = loadBoardViewport(boardID: boardID, in: context) {
            return BoardCanvasMath.visibleWorldCenter(viewport: savedViewport)
        }
        if let latest = existingPlacements.max(by: { $0.zIndex < $1.zIndex }) {
            return CGPoint(x: latest.x, y: latest.y)
        }
        return .zero
    }

    @MainActor
    static func stats(in context: ModelContext, directory: URL? = defaultDirectory) -> StickerStorageStats {
        let records = (try? context.fetch(FetchDescriptor<StickerRecord>())) ?? []
        guard !records.isEmpty else {
            return .empty
        }
        let recordedBytes = records.reduce(Int64(0)) { $0 + $1.byteSize }
        let diskBytes = directory.map { directorySize(at: $0) } ?? 0
        return StickerStorageStats(
            count: records.count,
            totalBytes: max(diskBytes, recordedBytes)
        )
    }

    @MainActor
    static func delete(_ record: StickerRecord, in context: ModelContext) throws {
        let targetID = record.id
        let allPlacements = (try? context.fetch(FetchDescriptor<BoardItemPlacement>())) ?? []
        for placement in allPlacements where placement.stickerID == targetID {
            context.delete(placement)
        }
        context.delete(record)
        try context.save()
        StickerThumbnailCache.shared.invalidate(targetID)
    }

    @MainActor
    static func deleteAll(in context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<StickerRecord>())
        for record in records {
            context.delete(record)
        }
        let orphanAssets = try context.fetch(FetchDescriptor<StickerAsset>())
        for asset in orphanAssets {
            context.delete(asset)
        }
        let placements = try context.fetch(FetchDescriptor<BoardItemPlacement>())
        for placement in placements {
            context.delete(placement)
        }
        let layouts = try context.fetch(FetchDescriptor<BoardLayoutRecord>())
        for layout in layouts {
            context.delete(layout)
        }
        try context.save()
        StickerThumbnailCache.shared.clear()
    }

    /// Recursively totals regular file sizes inside a storage directory.
    static func directorySize(at directory: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey],
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey]
            ), values.isRegularFile == true else {
                continue
            }
            if let size = values.fileSize {
                total += Int64(size)
            } else if let allocated = values.totalFileAllocatedSize {
                total += Int64(allocated)
            }
        }
        return total
    }
}
