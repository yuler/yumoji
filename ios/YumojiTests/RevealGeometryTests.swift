import CoreGraphics
import XCTest
@testable import Yumoji

final class RevealGeometryTests: XCTestCase {
    private func start(crop: PixelRect, photo: CGSize = CGSize(width: 400, height: 200)) -> RevealGeometry.Start? {
        RevealGeometry.start(photo: photo, crop: crop, available: CGSize(width: 200, height: 200))
    }

    func testCropCoveringWholePhotoStartsAtRest() throws {
        let result = try XCTUnwrap(start(crop: PixelRect(x: 0, y: 0, width: 400, height: 200)))
        XCTAssertEqual(result.scale, 1, accuracy: 0.0001)
        XCTAssertEqual(result.offset.width, 0, accuracy: 0.0001)
        XCTAssertEqual(result.offset.height, 0, accuracy: 0.0001)
    }

    func testCenteredCropStartsSmallerButNotMoved() throws {
        // The photo fits at 0.5 (400 px into 200 pt); the crop fits at 2.0 (100 px into 200 pt).
        let result = try XCTUnwrap(start(crop: PixelRect(x: 150, y: 50, width: 100, height: 100)))
        XCTAssertEqual(result.scale, 0.25, accuracy: 0.0001)
        XCTAssertEqual(result.offset.width, 0, accuracy: 0.0001)
        XCTAssertEqual(result.offset.height, 0, accuracy: 0.0001)
    }

    func testOffCenterCropMovesByItsDistanceFromTheCentre() throws {
        // Crop centre is (50, 150); photo centre is (200, 100); photo scale is 0.5.
        let result = try XCTUnwrap(start(crop: PixelRect(x: 0, y: 100, width: 100, height: 100)))
        XCTAssertEqual(result.offset.width, -75, accuracy: 0.0001)
        XCTAssertEqual(result.offset.height, 25, accuracy: 0.0001)
    }

    func testEmptySizesGiveNoStart() {
        XCTAssertNil(start(crop: PixelRect(x: 0, y: 0, width: 0, height: 10)))
        XCTAssertNil(start(crop: PixelRect(x: 0, y: 0, width: 10, height: 10), photo: .zero))
    }
}
