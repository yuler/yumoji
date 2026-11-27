import CoreGraphics
import XCTest
@testable import Yumoji

final class BoardCanvasMathTests: XCTestCase {
    func testWorldScreenRoundTripMatchesAtArbitraryViewport() {
        let viewport = BoardViewport(offset: CGSize(width: 48, height: -92), zoom: 1.65)
        let size = CGSize(width: 390, height: 780)
        let world = CGPoint(x: -120, y: 215)

        let screen = BoardCanvasMath.worldToScreen(world, viewport: viewport, viewportSize: size)
        let recovered = BoardCanvasMath.screenToWorld(screen, viewport: viewport, viewportSize: size)

        XCTAssertEqual(recovered.x, world.x, accuracy: 0.001)
        XCTAssertEqual(recovered.y, world.y, accuracy: 0.001)
    }

    func testFocalZoomKeepsAnchorWorldPointFixed() {
        let base = BoardViewport(offset: CGSize(width: 30, height: -20), zoom: 1.0)
        let size = CGSize(width: 400, height: 800)
        let anchor = CGPoint(x: 280, y: 260)

        let worldBefore = BoardCanvasMath.screenToWorld(anchor, viewport: base, viewportSize: size)
        let zoomed = BoardCanvasMath.zoomedViewport(
            from: base,
            magnification: 1.8,
            anchor: anchor,
            viewportSize: size
        )
        let worldAfter = BoardCanvasMath.screenToWorld(anchor, viewport: zoomed, viewportSize: size)

        XCTAssertEqual(zoomed.zoom, 1.8, accuracy: 0.001)
        XCTAssertEqual(worldAfter.x, worldBefore.x, accuracy: 0.01)
        XCTAssertEqual(worldAfter.y, worldBefore.y, accuracy: 0.01)
    }

    func testFitAllCentersItemsAndCapsZoomAtMaxZoom() {
        let viewportSize = CGSize(width: 400, height: 800)

        let single = [BoardItemGeometry(x: 300, y: -200, scale: 1.0, aspectRatio: 1.0)]
        let fitSingle = BoardCanvasMath.fitAll(items: single, viewportSize: viewportSize, maxZoom: 1.0)
        XCTAssertEqual(fitSingle.zoom, 1.0, accuracy: 0.001)
        let singleScreen = BoardCanvasMath.worldToScreen(
            CGPoint(x: 300, y: -200),
            viewport: fitSingle,
            viewportSize: viewportSize
        )
        XCTAssertEqual(singleScreen.x, viewportSize.width / 2, accuracy: 0.5)
        XCTAssertEqual(singleScreen.y, viewportSize.height / 2, accuracy: 0.5)

        let spread = [
            BoardItemGeometry(x: -500, y: -400, scale: 1.0, aspectRatio: 1.0),
            BoardItemGeometry(x: 500, y: 400, scale: 1.0, aspectRatio: 1.0)
        ]
        let fitSpread = BoardCanvasMath.fitAll(items: spread, viewportSize: viewportSize)
        XCTAssertLessThan(fitSpread.zoom, 0.5)
        XCTAssertGreaterThanOrEqual(fitSpread.zoom, BoardCanvasMath.minCanvasZoom)
    }

    func testSnapRotationSnapsWithinThresholdAndPreservesOutside() {
        let within = BoardCanvasMath.snapRotation(3.0 * .pi / 180.0)
        XCTAssertTrue(within.snapped)
        XCTAssertEqual(within.radians, 0, accuracy: 0.0001)

        let negativeWithin = BoardCanvasMath.snapRotation(-3.5 * .pi / 180.0)
        XCTAssertTrue(negativeWithin.snapped)
        XCTAssertEqual(negativeWithin.radians, 0, accuracy: 0.0001)

        let outside = BoardCanvasMath.snapRotation(12.0 * .pi / 180.0)
        XCTAssertFalse(outside.snapped)
        XCTAssertEqual(outside.radians, 12.0 * .pi / 180.0, accuracy: 0.0001)
    }

    func testLegacyMigrationCentersOriginalMidpoint() {
        let migrated = BoardCanvasMath.migrateLegacyCoordinate(normalizedX: 0.5, legacyY: 260)
        XCTAssertEqual(migrated.x, 0, accuracy: 0.001)
        XCTAssertEqual(migrated.y, 0, accuracy: 0.001)
    }
}
