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

/// Manages the local SwiftData store (SQLite + external binary assets) and storage stats.
enum StickerStorage {
    static let schema = Schema([StickerRecord.self, StickerAsset.self])

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

    /// Computes a gentle, non-overlapping initial drop position near the current viewport center.
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

    @MainActor
    static func saveSticker(
        _ image: CGImage,
        capturedAt: Date?,
        preferredY: Double,
        in context: ModelContext
    ) throws -> StickerRecord {
        guard let prepared = StickerImageSizer.prepareForStorage(image) else {
            throw StickerStorageError.encodingFailed
        }

        let existing = (try? context.fetch(FetchDescriptor<StickerRecord>())) ?? []
        let maxZ = existing.map(\.zIndex).max() ?? 0
        let placement = nextPlacement(
            existingCount: existing.count,
            maxZIndex: maxZ,
            preferredY: preferredY
        )

        let asset = StickerAsset(pngData: prepared.pngData)
        let record = StickerRecord(
            capturedAt: capturedAt,
            x: placement.x,
            y: placement.y,
            scale: 1.0,
            rotation: placement.rotation,
            zIndex: placement.zIndex,
            pixelWidth: prepared.pixelWidth,
            pixelHeight: prepared.pixelHeight,
            byteSize: prepared.byteSize,
            thumbnailData: prepared.thumbnailData,
            asset: asset
        )
        asset.sticker = record
        context.insert(record)
        try context.save()
        return record
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
        context.delete(record)
        try context.save()
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
        try context.save()
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
