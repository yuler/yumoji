import CoreGraphics
import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

/// PNG bytes for a sticker. Transparency in `image` is kept.
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
