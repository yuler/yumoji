import CoreGraphics
import ImageIO
import Photos
import XCTest
@testable import Yumoji

final class StickerExportTests: XCTestCase {
    func testPNGKeepsTransparentPixels() throws {
        let image = try XCTUnwrap(rgbaImage(pixels: [
            [0, 0, 0, 0],
            [255, 0, 0, 255],
        ]))
        let data = try XCTUnwrap(StickerPNG.data(from: image))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let pixels = try XCTUnwrap(PixelReader(decoded))

        XCTAssertEqual(pixels.width, 2)
        XCTAssertEqual(pixels.pixel(x: 0, y: 0).a, 0)
        XCTAssertEqual(pixels.pixel(x: 1, y: 0), RGBA(r: 255, g: 0, b: 0, a: 255))
    }

    func testOnlyAuthorizedAddAccessCanSave() {
        XCTAssertTrue(PhotoLibraryAddAccess.isAllowed(.authorized))
        XCTAssertFalse(PhotoLibraryAddAccess.isAllowed(.denied))
        XCTAssertFalse(PhotoLibraryAddAccess.isAllowed(.restricted))
        XCTAssertFalse(PhotoLibraryAddAccess.isAllowed(.notDetermined))
        XCTAssertFalse(PhotoLibraryAddAccess.isAllowed(.limited))
    }

    private func rgbaImage(pixels: [[UInt8]]) -> CGImage? {
        let height = pixels.count
        let width = pixels[0].count / 4
        let bytes = pixels.flatMap { $0 }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
