import CoreGraphics
import ImageIO
import Photos
import XCTest
@testable import Yumoji

final class StickerExportTests: XCTestCase {
    func testPNGKeepsTransparentPixels() throws {
        let image = try XCTUnwrap(rgbaImage(pixels: [
            [0, 0, 0, 0, 255, 0, 0, 255],
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

    func testRendererTransparentReturnsOriginalImage() throws {
        let sticker = TestImages.solid(width: 200, height: 100, color: RGB(r: 240, g: 80, b: 40))
        let rendered = try XCTUnwrap(StickerExportRenderer.render(sticker, background: .transparent))
        XCTAssertEqual(rendered.width, 200)
        XCTAssertEqual(rendered.height, 100)
    }

    func testRendererSolidProducesSquareCardWithBackgroundAndCenteredSticker() throws {
        let sticker = TestImages.solid(width: 400, height: 200, color: RGB(r: 30, g: 140, b: 220))
        let bg = RGBAColor(hex: 0xFDEBD2)
        let rendered = try XCTUnwrap(StickerExportRenderer.render(sticker, background: .solid(bg)))

        XCTAssertEqual(rendered.width, rendered.height)
        XCTAssertGreaterThanOrEqual(rendered.width, StickerExportRenderer.minSquareSide)
        XCTAssertLessThanOrEqual(rendered.width, StickerExportRenderer.maxSquareSide)

        let pixels = try XCTUnwrap(PixelReader(rendered))
        let corner = pixels.pixel(x: 4, y: 4)
        XCTAssertEqual(corner.a, 255)
        XCTAssertLessThanOrEqual(abs(Int(corner.r) - 0xFD), 2)
        XCTAssertLessThanOrEqual(abs(Int(corner.g) - 0xEB), 2)
        XCTAssertLessThanOrEqual(abs(Int(corner.b) - 0xD2), 2)

        let center = pixels.pixel(x: rendered.width / 2, y: rendered.height / 2)
        XCTAssertLessThanOrEqual(abs(Int(center.r) - 30), 3)
        XCTAssertLessThanOrEqual(abs(Int(center.g) - 140), 3)
        XCTAssertLessThanOrEqual(abs(Int(center.b) - 220), 3)
    }

    @MainActor
    func testExportPaletteStorePersistsSelectionAndCustomSwatches() {
        let suiteName = "cc.yuler.yumoji.tests.palette.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ExportPaletteStore(defaults: defaults)
        XCTAssertEqual(store.selected, .transparent)
        XCTAssertTrue(store.customColors.isEmpty)

        // Live drag updates draft in-place instead of filling multiple slots.
        let draft1 = store.applyPickedColor(RGBAColor(hex: 0x112233), replacing: nil)
        let draft2 = store.applyPickedColor(RGBAColor(hex: 0x445566), replacing: draft1)
        XCTAssertEqual(store.customColors.map(\.hexString), ["#445566"])
        XCTAssertEqual(store.selected, .solid(draft2))

        // Adding more distinct colors caps at maxCustomColors.
        let extraHexes: [UInt] = [0xAA1122, 0xBB2233, 0xCC3344, 0xDD4455, 0xEE5566, 0xFF6677]
        for hex in extraHexes {
            store.applyPickedColor(RGBAColor(hex: hex), replacing: nil)
        }
        XCTAssertEqual(store.customColors.count, ExportPaletteStore.maxCustomColors)
        XCTAssertEqual(store.customColors.first?.hexString, "#FF6677")

        // Reload from UserDefaults verifies persistence.
        let restored = ExportPaletteStore(defaults: defaults)
        XCTAssertEqual(restored.customColors.map(\.hexString), store.customColors.map(\.hexString))
        XCTAssertEqual(restored.selected, .solid(RGBAColor(hex: 0xFF6677)))

        // Removing the active custom color falls back to transparent.
        restored.removeCustomColor(RGBAColor(hex: 0xFF6677))
        XCTAssertEqual(restored.selected, .transparent)
        XCTAssertFalse(restored.customColors.contains { $0.hexString == "#FF6677" })
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
