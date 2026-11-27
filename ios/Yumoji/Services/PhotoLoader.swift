import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// Upright bitmap decoded from a photo along with its EXIF capture date if available.
struct DecodedPhoto: Sendable {
    let image: CGImage
    let capturedAt: Date?
}

/// Decodes a chosen photo into an upright, working-size bitmap. Everything
/// downstream (cutout, sticker) assumes the image is already upright.
enum PhotoLoader {
    /// Long side of the working image in pixels. Plenty for a sticker, and
    /// small enough that re-rendering while dragging a slider stays quick.
    static let workingLongSide = 2048

    /// Decodes encoded image data (JPEG, HEIC, PNG...), applying the EXIF
    /// orientation to the pixels and scaling down to `longSide` if larger.
    static func decode(_ data: Data, longSide: Int = PhotoLoader.workingLongSide) -> CGImage? {
        decodeWithMetadata(data, longSide: longSide)?.image
    }

    /// Decodes encoded image data and extracts the EXIF capture date when present.
    static func decodeWithMetadata(_ data: Data, longSide: Int = PhotoLoader.workingLongSide) -> DecodedPhoto? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return DecodedPhoto(image: image, capturedAt: capturedDate(from: source))
    }

    /// Reads EXIF capture date from encoded photo bytes without decoding the pixels.
    static func capturedDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return capturedDate(from: source)
    }

    /// Camera photos arrive as a `UIImage` whose orientation is a flag rather
    /// than baked into the pixels. Going through JPEG lets `decode` fix that.
    static func decode(_ image: UIImage, longSide: Int = PhotoLoader.workingLongSide) -> CGImage? {
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            return nil
        }
        return decode(data, longSide: longSide)
    }

    private static func capturedDate(from source: CGImageSource) -> Date? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let raw = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (exif?[kCGImagePropertyExifDateTimeDigitized] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)
        guard let raw else { return nil }
        return parseExifDate(raw)
    }

    static func parseExifDate(_ raw: String, timeZone: TimeZone = .current) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: trimmed)
    }
}
