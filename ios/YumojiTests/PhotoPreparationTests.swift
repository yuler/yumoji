import CoreGraphics
import UIKit
import XCTest
@testable import Yumoji

/// The upload image helper and the photo decoder.
final class PhotoPreparationTests: XCTestCase {
    private let red = RGB(r: 220, g: 40, b: 40)
    private let blue = RGB(r: 40, g: 60, b: 220)

    // MARK: - Upload image

    func testScaledSizeBringsLongSideTo1024AndKeepsAspectRatio() {
        let landscape = UploadImage.scaledSize(width: 4032, height: 3024)
        XCTAssertEqual(landscape.width, 1024)
        XCTAssertEqual(landscape.height, 768)

        let portrait = UploadImage.scaledSize(width: 3024, height: 4032)
        XCTAssertEqual(portrait.width, 768)
        XCTAssertEqual(portrait.height, 1024)
    }

    func testScaledSizeNeverUpscales() {
        let small = UploadImage.scaledSize(width: 800, height: 600)
        XCTAssertEqual(small.width, 800)
        XCTAssertEqual(small.height, 600)

        let exact = UploadImage.scaledSize(width: 1024, height: 1024)
        XCTAssertEqual(exact.width, 1024)
        XCTAssertEqual(exact.height, 1024)
    }

    func testUploadDataIsJPEGWithLongSide1024() throws {
        let photo = TestImages.solid(width: 1600, height: 800, color: red)
        let data = try XCTUnwrap(UploadImage.jpegData(from: photo))

        // JPEG files start with the SOI marker FF D8.
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8])

        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertEqual(decoded.width, 1024)
        XCTAssertEqual(decoded.height, 512)
    }

    func testUploadDataKeepsSmallImagesAtTheirSize() throws {
        let photo = TestImages.solid(width: 300, height: 200, color: blue)
        let data = try XCTUnwrap(UploadImage.jpegData(from: photo))

        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertEqual(decoded.width, 300)
        XCTAssertEqual(decoded.height, 200)
    }

    // MARK: - Photo decoder

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
    }
}
