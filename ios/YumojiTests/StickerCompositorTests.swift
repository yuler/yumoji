import CoreGraphics
import XCTest
@testable import Yumoji

/// Synthetic photo and mask only: Vision does not run in the simulator.
final class StickerCompositorTests: XCTestCase {
    // A 320 x 240 photo, red above row 110 and blue below, with a circular
    // subject of radius 50 centred at (140, 100). The two colours make a
    // vertically flipped or shifted sticker show up as a wrong pixel.
    private let photoWidth = 320
    private let photoHeight = 240
    private let centerX = 140
    private let centerY = 100
    private let radius = 50
    private let splitRow = 110
    private let red = RGB(r: 220, g: 60, b: 40)
    private let blue = RGB(r: 40, g: 90, b: 200)

    /// Width and height of the bare subject: the circle covers 2 * 50 + 1 pixels.
    private let subjectSide = 101

    private func makePhoto() -> CGImage {
        TestImages.image(width: photoWidth, height: photoHeight) { _, y in
            y < self.splitRow ? self.red : self.blue
        }
    }

    private func makeMask() -> SubjectMask {
        TestImages.circleMask(
            width: photoWidth,
            height: photoHeight,
            centerX: centerX,
            centerY: centerY,
            radius: radius
        )
    }

    private func assertColor(
        _ pixel: RGBA,
        isCloseTo expected: RGB,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(Double(pixel.r), Double(expected.r), accuracy: 6, "red", file: file, line: line)
        XCTAssertEqual(Double(pixel.g), Double(expected.g), accuracy: 6, "green", file: file, line: line)
        XCTAssertEqual(Double(pixel.b), Double(expected.b), accuracy: 6, "blue", file: file, line: line)
        XCTAssertGreaterThanOrEqual(pixel.a, 250, "alpha", file: file, line: line)
    }

    func testMaskBoundsMatchTheCircle() {
        XCTAssertEqual(
            makeMask().bounds,
            PixelRect(x: 90, y: 50, width: subjectSide, height: subjectSide)
        )
    }

    func testStickerHasWhiteBorderTransparentCornersAndOriginalSubject() throws {
        // Border 0.1 * 101 = about 10 px, margin about 5 px.
        let style = StickerStyle(borderRatio: 0.1, edgeSmoothing: 0.25, marginRatio: 0.05)
        let sticker = try XCTUnwrap(
            StickerCompositor.makeSticker(image: makePhoto(), mask: makeMask(), style: style)
        )
        let pixels = try XCTUnwrap(PixelReader(sticker))

        // Larger than the bare subject by the border on both sides, and not much more.
        XCTAssertEqual(sticker.width, sticker.height)
        XCTAssertGreaterThanOrEqual(sticker.width, subjectSide + 2 * 10)
        XCTAssertLessThanOrEqual(sticker.width, subjectSide + 2 * (10 + 5) + 6)

        let midX = sticker.width / 2
        let midY = sticker.height / 2

        // The subject keeps the photo's colours, the right way up.
        assertColor(pixels.pixel(x: midX, y: midY), isCloseTo: red)
        assertColor(pixels.pixel(x: midX, y: midY - 35), isCloseTo: red)
        assertColor(pixels.pixel(x: midX, y: midY + 35), isCloseTo: blue)

        // 55 px from the centre is inside the border ring (50...60): opaque white.
        let white = RGB(r: 255, g: 255, b: 255)
        assertColor(pixels.pixel(x: midX + 55, y: midY), isCloseTo: white)
        assertColor(pixels.pixel(x: midX - 55, y: midY), isCloseTo: white)
        assertColor(pixels.pixel(x: midX, y: midY - 55), isCloseTo: white)
        assertColor(pixels.pixel(x: midX, y: midY + 55), isCloseTo: white)

        // 65 px out is past the border, in the transparent margin.
        XCTAssertEqual(pixels.pixel(x: midX + 65, y: midY).a, 0)
        XCTAssertEqual(pixels.pixel(x: midX - 65, y: midY).a, 0)

        // Corners are transparent.
        let lastX = sticker.width - 1
        let lastY = sticker.height - 1
        XCTAssertEqual(pixels.pixel(x: 0, y: 0).a, 0)
        XCTAssertEqual(pixels.pixel(x: lastX, y: 0).a, 0)
        XCTAssertEqual(pixels.pixel(x: 0, y: lastY).a, 0)
        XCTAssertEqual(pixels.pixel(x: lastX, y: lastY).a, 0)
    }

    func testBorderWidthFollowsTheStyle() throws {
        let photo = makePhoto()
        let mask = makeMask()
        let thin = try XCTUnwrap(StickerCompositor.makeSticker(
            image: photo,
            mask: mask,
            style: StickerStyle(borderRatio: 0.02, edgeSmoothing: 0.25, marginRatio: 0.05)
        ))
        let thick = try XCTUnwrap(StickerCompositor.makeSticker(
            image: photo,
            mask: mask,
            style: StickerStyle(borderRatio: 0.1, edgeSmoothing: 0.25, marginRatio: 0.05)
        ))
        XCTAssertGreaterThan(thick.width, thin.width)

        // With a 2 px border, 55 px from the centre is already transparent.
        let pixels = try XCTUnwrap(PixelReader(thin))
        XCTAssertEqual(pixels.pixel(x: thin.width / 2 + 55, y: thin.height / 2).a, 0)
    }

    func testZeroBorderLeavesJustTheSubject() throws {
        let style = StickerStyle(borderRatio: 0, edgeSmoothing: 0.25, marginRatio: 0)
        let sticker = try XCTUnwrap(
            StickerCompositor.makeSticker(image: makePhoto(), mask: makeMask(), style: style)
        )
        let pixels = try XCTUnwrap(PixelReader(sticker))

        XCTAssertGreaterThanOrEqual(sticker.width, subjectSide)
        XCTAssertLessThanOrEqual(sticker.width, subjectSide + 4)
        assertColor(pixels.pixel(x: sticker.width / 2, y: sticker.height / 2), isCloseTo: red)
        XCTAssertEqual(pixels.pixel(x: 0, y: 0).a, 0)
    }

    func testEmptyMaskGivesNoSticker() {
        let empty = SubjectMask(
            width: photoWidth,
            height: photoHeight,
            pixels: [UInt8](repeating: 0, count: photoWidth * photoHeight)
        )
        XCTAssertNil(empty.bounds)
        XCTAssertNil(StickerCompositor.makeSticker(image: makePhoto(), mask: empty, style: StickerStyle()))
    }

    func testBorderWidthScalesWithSubjectSize() {
        let style = StickerStyle(borderRatio: 0.05, edgeSmoothing: 0.25, marginRatio: 0.02)
        XCTAssertEqual(style.borderWidth(subjectLongSide: 200), 10, accuracy: 0.001)
        XCTAssertEqual(style.borderWidth(subjectLongSide: 2000), 100, accuracy: 0.001)
        XCTAssertEqual(style.marginWidth(subjectLongSide: 1000), 20, accuracy: 0.001)
    }
}
