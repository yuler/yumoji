import CoreGraphics
import SwiftData
import UIKit
import XCTest
@testable import Yumoji

final class StickerStorageTests: XCTestCase {
    func testStickerImageSizerScalesDownTo1024And320WithoutUpscaling() throws {
        let large = TestImages.solid(width: 2048, height: 1024, color: RGB(r: 220, g: 90, b: 40))
        let preparedLarge = try XCTUnwrap(StickerImageSizer.prepareForStorage(large))
        XCTAssertEqual(preparedLarge.pixelWidth, 1024)
        XCTAssertEqual(preparedLarge.pixelHeight, 512)
        XCTAssertGreaterThan(preparedLarge.pngData.count, 0)
        XCTAssertGreaterThan(preparedLarge.thumbnailData.count, 0)

        let thumbImage = try XCTUnwrap(UIImage(data: preparedLarge.thumbnailData)?.cgImage)
        XCTAssertEqual(thumbImage.width, 320)
        XCTAssertEqual(thumbImage.height, 160)

        let small = TestImages.solid(width: 240, height: 180, color: RGB(r: 50, g: 160, b: 90))
        let preparedSmall = try XCTUnwrap(StickerImageSizer.prepareForStorage(small))
        XCTAssertEqual(preparedSmall.pixelWidth, 240)
        XCTAssertEqual(preparedSmall.pixelHeight, 180)
    }

    func testNextPlacementIncrementsZIndexAndStaysWithinBounds() {
        let first = StickerStorage.nextPlacement(existingCount: 0, maxZIndex: 0, preferredY: 200)
        let second = StickerStorage.nextPlacement(existingCount: 1, maxZIndex: first.zIndex, preferredY: 200)

        XCTAssertEqual(first.zIndex, 1)
        XCTAssertEqual(second.zIndex, 2)
        XCTAssertNotEqual(first.x, second.x)
        XCTAssertTrue((0.16...0.84).contains(first.x))
        XCTAssertTrue((0.16...0.84).contains(second.x))
        XCTAssertGreaterThanOrEqual(first.y, 130)
        XCTAssertGreaterThanOrEqual(second.y, 130)
    }

    func testStickerRecordTagEncodingRoundTrip() {
        let record = StickerRecord(tags: ["  cat ", "", "favorite", "trip"])
        XCTAssertEqual(record.tags, ["cat", "favorite", "trip"])

        record.tags = []
        XCTAssertNil(record.tagsText)
        XCTAssertEqual(record.tags, [])
    }

    @MainActor
    func testSaveFetchStatsAndDeleteAllOnDiskStore() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("YumojiStorageTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let container = try StickerStorage.makeContainer(inMemory: false, directory: tempDir)
        let context = container.mainContext

        XCTAssertEqual(StickerStorage.stats(in: context, directory: tempDir), .empty)

        let stickerA = TestImages.solid(width: 600, height: 400, color: RGB(r: 230, g: 70, b: 70))
        let stickerB = TestImages.solid(width: 400, height: 600, color: RGB(r: 60, g: 130, b: 230))
        let captureDate = Date(timeIntervalSince1970: 1_750_000_000)

        let savedA = try StickerStorage.saveSticker(
            stickerA,
            capturedAt: captureDate,
            preferredY: 240,
            in: context
        )
        let savedB = try StickerStorage.saveSticker(
            stickerB,
            capturedAt: nil,
            preferredY: 280,
            in: context
        )

        XCTAssertEqual(savedA.capturedAt, captureDate)
        XCTAssertEqual(savedA.pixelWidth, 600)
        XCTAssertEqual(savedA.pixelHeight, 400)
        XCTAssertNotNil(savedA.thumbnailData)
        XCTAssertNotNil(savedA.asset?.pngData)
        XCTAssertGreaterThan(savedB.zIndex, savedA.zIndex)

        let stats = StickerStorage.stats(in: context, directory: tempDir)
        XCTAssertEqual(stats.count, 2)
        XCTAssertGreaterThanOrEqual(stats.totalBytes, savedA.byteSize + savedB.byteSize)

        try StickerStorage.delete(savedA, in: context)
        let afterSingleDelete = StickerStorage.stats(in: context, directory: tempDir)
        XCTAssertEqual(afterSingleDelete.count, 1)

        try StickerStorage.deleteAll(in: context)
        let afterClear = StickerStorage.stats(in: context, directory: tempDir)
        XCTAssertEqual(afterClear, .empty)

        let remainingRecords = try context.fetch(FetchDescriptor<StickerRecord>())
        let remainingAssets = try context.fetch(FetchDescriptor<StickerAsset>())
        let remainingPlacements = try context.fetch(FetchDescriptor<BoardItemPlacement>())
        let remainingLayouts = try context.fetch(FetchDescriptor<BoardLayoutRecord>())
        XCTAssertTrue(remainingRecords.isEmpty)
        XCTAssertTrue(remainingAssets.isEmpty)
        XCTAssertTrue(remainingPlacements.isEmpty)
        XCTAssertTrue(remainingLayouts.isEmpty)
    }

    @MainActor
    func testDecoupledBoardViewportAndLegacyPlacementMigration() throws {
        let container = try StickerStorage.makeContainer(inMemory: true)
        let context = container.mainContext

        // Insert a legacy StickerRecord without a BoardItemPlacement.
        let legacy = StickerRecord(x: 0.75, y: 310, scale: 1.4, rotation: 0.25, zIndex: 7)
        context.insert(legacy)
        try context.save()

        let migrated = StickerStorage.ensureBoardPlacements(for: [legacy], in: context)
        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(migrated[0].stickerID, legacy.id)
        XCTAssertEqual(migrated[0].scale, 1.4, accuracy: 0.001)
        XCTAssertEqual(migrated[0].rotation, 0.25, accuracy: 0.001)
        XCTAssertEqual(migrated[0].zIndex, 7)

        XCTAssertNil(StickerStorage.loadBoardViewport(in: context))
        let savedViewport = BoardViewport(offset: CGSize(width: -120, height: 85), zoom: 1.35)
        StickerStorage.saveBoardViewport(savedViewport, in: context)

        let loadedViewport = try XCTUnwrap(StickerStorage.loadBoardViewport(in: context))
        XCTAssertEqual(loadedViewport.offset.width, -120, accuracy: 0.01)
        XCTAssertEqual(loadedViewport.offset.height, 85, accuracy: 0.01)
        XCTAssertEqual(loadedViewport.zoom, 1.35, accuracy: 0.001)
    }

    @MainActor
    func testStickerSessionProducesStickerWithoutFoodAnalyzer() async throws {
        let photo = TestImages.solid(width: 120, height: 120, color: RGB(r: 210, g: 120, b: 60))
        let fakeLifter = StubSubjectLifter(mask: SubjectMask(
            width: 120,
            height: 120,
            pixels: (0..<(120 * 120)).map { idx in
                let x = idx % 120
                let y = idx / 120
                return (30..<90).contains(x) && (30..<90).contains(y) ? 255 : 0
            }
        ))

        let session = StickerSession(lifter: fakeLifter)
        session.start(.camera(UIImage(cgImage: photo)))

        for _ in 0..<60 {
            if session.cutout == .ready { break }
            try await Task.sleep(for: .milliseconds(30))
        }

        XCTAssertEqual(session.cutout, .ready)
        XCTAssertNotNil(session.sticker)
        XCTAssertNotNil(session.capturedAt)
    }
}

private struct StubSubjectLifter: SubjectLifting {
    let mask: SubjectMask
    func liftSubject(from image: CGImage) async throws -> SubjectMask {
        mask
    }
}
