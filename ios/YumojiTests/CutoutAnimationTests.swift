import CoreGraphics
import XCTest
@testable import Yumoji

final class CutoutAnimationTests: XCTestCase {
    func testFrameFollowsAspectUntilTheCap() {
        let wide = StageLayout.frame(image: CGSize(width: 1000, height: 500), containerWidth: 300)
        XCTAssertEqual(wide.width, 300, accuracy: 0.001)
        XCTAssertEqual(wide.height, 150, accuracy: 0.001)

        let tall = StageLayout.frame(image: CGSize(width: 1000, height: 3000), containerWidth: 300)
        XCTAssertEqual(tall.width, 300, accuracy: 0.001)
        XCTAssertEqual(tall.height, StageLayout.maxHeight, accuracy: 0.001)
        XCTAssertEqual(StageLayout.frame(image: .zero, containerWidth: 300).height, 0, accuracy: 0.001)
    }

    func testFittedRectLetterboxesATallPhotoInsideTheCap() {
        let frame = CGSize(width: 300, height: 480)
        let fitted = StageLayout.fittedRect(image: CGSize(width: 1000, height: 2000), frame: frame)
        XCTAssertEqual(fitted.width, 240, accuracy: 0.001)
        XCTAssertEqual(fitted.height, 480, accuracy: 0.001)
        XCTAssertEqual(fitted.minX, 30, accuracy: 0.001)
        XCTAssertEqual(fitted.minY, 0, accuracy: 0.001)

        let mapped = StageLayout.map(CGPoint(x: 500, y: 1000), image: CGSize(width: 1000, height: 2000), fitted: fitted)
        XCTAssertEqual(mapped.x, 150, accuracy: 0.001)
        XCTAssertEqual(mapped.y, 240, accuracy: 0.001)
    }

    func testRectangleOutlineStaysOnTheBoundary() {
        let width = 48
        let height = 36
        var pixels = [UInt8](repeating: 0, count: width * height)
        let originX = 10
        let originY = 8
        let rectWidth = 20
        let rectHeight = 14
        for y in originY..<(originY + rectHeight) {
            for x in originX..<(originX + rectWidth) {
                pixels[y * width + x] = 255
            }
        }

        let points = ContourPath.trace(width: width, height: height, pixels: pixels, maxSide: 120)
        XCTAssertGreaterThan(points.count, 8)
        XCTAssertEqual(points.map(\.x).min() ?? 0, CGFloat(originX) + 0.5, accuracy: 1.5)
        XCTAssertEqual(points.map(\.x).max() ?? 0, CGFloat(originX + rectWidth) - 0.5, accuracy: 1.5)
        XCTAssertEqual(points.map(\.y).min() ?? 0, CGFloat(originY) + 0.5, accuracy: 1.5)
        XCTAssertEqual(points.map(\.y).max() ?? 0, CGFloat(originY + rectHeight) - 0.5, accuracy: 1.5)
    }

    func testTraceFollowsTheLargerShape() {
        let width = 60
        let height = 60
        var pixels = [UInt8](repeating: 0, count: width * height)
        fill(&pixels, width: width, rect: CGRect(x: 0, y: 0, width: 4, height: 4))
        fill(&pixels, width: width, rect: CGRect(x: 24, y: 20, width: 18, height: 18))

        let points = ContourPath.trace(width: width, height: height, pixels: pixels, maxSide: 120)
        XCTAssertGreaterThan(points.map(\.x).min() ?? 0, 15)
    }

    func testCircleOutlineSitsNearTheRadius() {
        let mask = TestImages.circleMask(width: 100, height: 100, centerX: 50, centerY: 50, radius: 20)
        let points = ContourPath.trace(width: mask.width, height: mask.height, pixels: mask.pixels, maxSide: 120)
        XCTAssertGreaterThan(points.count, 12)
        for point in points {
            let distance = hypot(point.x - 50, point.y - 50)
            XCTAssertGreaterThan(distance, 14)
            XCTAssertLessThan(distance, 26)
        }
    }

    func testEmptyMaskHasNoOutline() {
        XCTAssertTrue(ContourPath.trace(width: 4, height: 4, pixels: [UInt8](repeating: 0, count: 16)).isEmpty)
        XCTAssertTrue(ContourPath.trace(width: 2, height: 2, pixels: [255]).isEmpty)
    }

    func testSampleWalksAClosedSquare() {
        let square = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 0, y: 10),
        ]
        let start = ContourPath.sample(points: square, progress: 0)
        XCTAssertEqual(start?.point.x ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(start?.point.y ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(start?.angle ?? -1, 0, accuracy: 0.001)

        let halfway = ContourPath.sample(points: square, progress: 0.5)
        XCTAssertEqual(halfway?.point.x ?? -1, 10, accuracy: 0.001)
        XCTAssertEqual(halfway?.point.y ?? -1, 10, accuracy: 0.001)

        let end = ContourPath.sample(points: square, progress: 1)
        XCTAssertEqual(end?.point.x ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(end?.point.y ?? -1, 0, accuracy: 0.001)
        XCTAssertNil(ContourPath.sample(points: [], progress: 0.5))
    }

    func testOutsideMaskPunchesOutTheSubject() {
        let mask = TestImages.circleMask(width: 100, height: 100, centerX: 50, centerY: 50, radius: 20)
        let bitmap = OutsideMask.bitmap(width: mask.width, height: mask.height, pixels: mask.pixels, maxSide: 320)
        let image = try XCTUnwrap(bitmap)
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 100)
        XCTAssertEqual(alpha(image, x: 50, y: 50), 0)
        XCTAssertEqual(alpha(image, x: 0, y: 0), 255)
        XCTAssertNotNil(image.cgImage())
    }

    func testSoundsArePlayableWavs() {
        for data in [StageWAV.paperCut(), StageWAV.dong()] {
            XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
            XCTAssertEqual(String(data: data.dropFirst(8).prefix(4), encoding: .ascii), "WAVE")
            XCTAssertGreaterThan(data.count, 44)
            var energy = 0
            data.dropFirst(44).withUnsafeBytes { bytes in
                for sample in bytes.bindMemory(to: Int16.self) {
                    energy += Int(abs(Int32(sample)))
                }
            }
            XCTAssertGreaterThan(energy, 0)
        }
    }

    private func fill(_ pixels: inout [UInt8], width: Int, rect: CGRect) {
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                pixels[y * width + x] = 255
            }
        }
    }

    private func alpha(_ bitmap: OutsideMask.Bitmap, x: Int, y: Int) -> UInt8 {
        bitmap.rgba[(y * bitmap.width + x) * 4 + 3]
    }
}

@MainActor
final class SoundEffectsTests: XCTestCase {
    func testDefaultsToOnAndPersistsOff() {
        let suiteName = "cc.yuler.yumoji.tests.sound.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = SoundEffects(defaults: defaults)
        XCTAssertTrue(first.isEnabled)

        first.isEnabled = false
        XCTAssertEqual(defaults.bool(forKey: SoundEffects.storageKey), false)

        let restored = SoundEffects(defaults: defaults)
        XCTAssertFalse(restored.isEnabled)
    }
}
