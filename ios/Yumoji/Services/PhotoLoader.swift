import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// Decodes a chosen photo into an upright, working-size bitmap. Everything
/// downstream (cutout, sticker, upload) assumes the image is already upright.
enum PhotoLoader {
    /// Long side of the working image in pixels. Plenty for a sticker, and
    /// small enough that re-rendering while dragging a slider stays quick.
    static let workingLongSide = 2048

    /// Decodes encoded image data (JPEG, HEIC, PNG...), applying the EXIF
    /// orientation to the pixels and scaling down to `longSide` if larger.
    static func decode(_ data: Data, longSide: Int = PhotoLoader.workingLongSide) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Camera photos arrive as a `UIImage` whose orientation is a flag rather
    /// than baked into the pixels. Going through JPEG lets `decode` fix that.
    static func decode(_ image: UIImage, longSide: Int = PhotoLoader.workingLongSide) -> CGImage? {
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            return nil
        }
        return decode(data, longSide: longSide)
    }
}
