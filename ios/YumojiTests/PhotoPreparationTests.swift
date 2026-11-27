import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Yumoji

/// Photo decoding and EXIF capture-date extraction.
final class PhotoPreparationTests: XCTestCase {
    private let red = RGB(r: 220, g: 40, b: 40)
    private let blue = RGB(r: 40, g: 60, b: 220)

    func testDecodeBakesOrientationIntoPixels() throws {
        // Stored pixels are 60 x 40, left half red and right half blue, flagged
        // `.right` the way a portrait camera photo is. Upright that is 40 x 60
        // with red on top.
        let stored = TestImages.image(width: 60, height: 40) { x, _ in
            x < 30 ? self.red : self.blue
        }
        let flagged = UIImage(cgImage: stored, scale: 1, orientation: .right)

        let upright = try XCTUnwrap(PhotoLoader.decode(flagged))
        XCTAssertEqual(upright.width, 40)
        XCTAssertEqual(upright.height, 60)

        let pixels = try XCTUnwrap(PixelReader(upright))
        let top = pixels.pixel(x: 20, y: 8)
        let bottom = pixels.pixel(x: 20, y: 52)
        XCTAssertGreaterThan(top.r, 150)
        XCTAssertLessThan(top.b, 110)
        XCTAssertGreaterThan(bottom.b, 150)
        XCTAssertLessThan(bottom.r, 110)
    }

    func testDecodeScalesDownButNotUp() throws {
        let photo = TestImages.solid(width: 400, height: 200, color: red)
        let data = try XCTUnwrap(UIImage(cgImage: photo).jpegData(compressionQuality: 0.9))

        let reduced = try XCTUnwrap(PhotoLoader.decode(data, longSide: 100))
        XCTAssertEqual(reduced.width, 100)
        XCTAssertEqual(reduced.height, 50)

        let untouched = try XCTUnwrap(PhotoLoader.decode(data, longSide: 2048))
        XCTAssertEqual(untouched.width, 400)
        XCTAssertEqual(untouched.height, 200)
    }

    func testDecodeRejectsDataThatIsNotAnImage() {
        XCTAssertNil(PhotoLoader.decode(Data("not an image".utf8)))
        XCTAssertNil(PhotoLoader.decodeWithMetadata(Data("not an image".utf8)))
    }

    func testParseExifDateHandlesStandardFormat() throws {
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let parsed = try XCTUnwrap(PhotoLoader.parseExifDate("2026:08:15 14:30:22", timeZone: utc))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: parsed)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 8)
        XCTAssertEqual(comps.day, 15)
        XCTAssertEqual(comps.hour, 14)
        XCTAssertEqual(comps.minute, 30)
        XCTAssertEqual(comps.second, 22)
        XCTAssertNil(PhotoLoader.parseExifDate("invalid"))
    }

    func testDecodeWithMetadataExtractsExifCaptureDate() throws {
        let photo = TestImages.solid(width: 120, height: 80, color: blue)
        let output = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        )
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:05:20 18:45:00",
            ],
        ]
        CGImageDestinationAddImage(destination, photo, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let decoded = try XCTUnwrap(PhotoLoader.decodeWithMetadata(output as Data))
        XCTAssertEqual(decoded.image.width, 120)
        XCTAssertEqual(decoded.image.height, 80)
        let expected = try XCTUnwrap(PhotoLoader.parseExifDate("2026:05:20 18:45:00"))
        XCTAssertEqual(decoded.capturedAt, expected)
    }
}
