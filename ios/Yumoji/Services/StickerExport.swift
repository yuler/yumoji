import CoreGraphics
import CoreTransferable
import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

/// PNG bytes for a sticker. Transparency in `image` is kept when present.
enum StickerPNG {
    static func data(from image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

/// Renders a sticker for export: tight transparent PNG when `.transparent`,
/// or a centered 1:1 square card when a solid background color is selected.
enum StickerExportRenderer {
    static let minSquareSide = 512
    static let maxSquareSide = 1280
    static let marginFraction = 0.09

    static func render(_ sticker: CGImage, background: ExportBackgroundOption) -> CGImage? {
        switch background {
        case .transparent:
            return sticker
        case .solid(let color):
            return renderSquareCard(sticker, background: color)
        }
    }

    private static func renderSquareCard(_ sticker: CGImage, background: RGBAColor) -> CGImage? {
        guard sticker.width > 0, sticker.height > 0 else { return nil }
        let longSide = max(sticker.width, sticker.height)
        let desired = Int((Double(longSide) / (1.0 - 2.0 * marginFraction)).rounded())
        let side = min(maxSquareSide, max(minSquareSide, desired))

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        let canvas = CGRect(x: 0, y: 0, width: side, height: side)
        context.setFillColor(background.cgColor)
        context.fill(canvas)

        let inset = Double(side) * marginFraction
        let available = Double(side) - 2.0 * inset
        let scale = available / Double(longSide)
        let drawWidth = Double(sticker.width) * scale
        let drawHeight = Double(sticker.height) * scale
        let drawRect = CGRect(
            x: (Double(side) - drawWidth) / 2.0,
            y: (Double(side) - drawHeight) / 2.0,
            width: drawWidth,
            height: drawHeight
        )
        context.interpolationQuality = .high
        context.draw(sticker, in: drawRect)
        return context.makeImage()
    }
}

/// A sticker PNG handed to the system share sheet, named `Yumoji.png`.
struct StickerPNGFile: Transferable {
    let image: CGImage

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { item in
            guard let data = StickerPNG.data(from: item.image) else {
                throw StickerSaveError.failed
            }
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("Yumoji.png")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

enum StickerSaveError: Error, Equatable {
    case denied
    case failed
}

/// Add-only photo library access. `.limited` is a read-write state and cannot add stickers here.
enum PhotoLibraryAddAccess {
    static func isAllowed(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized
    }
}

protocol StickerLibrarySaving: Sendable {
    func savePNG(_ data: Data) async throws
}

struct PhotoLibraryStickerSaver: StickerLibrarySaving {
    func savePNG(_ data: Data) async throws {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard PhotoLibraryAddAccess.isAllowed(status) else {
            throw StickerSaveError.denied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let creation = PHAssetCreationRequest.forAsset()
                creation.addResource(with: .photo, data: data, options: nil)
            }
        } catch {
            throw StickerSaveError.failed
        }
    }
}
