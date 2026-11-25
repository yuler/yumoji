import CoreGraphics
import UIKit

/// Prepares the photo that gets uploaded for analysis: the original photo
/// scaled down so its long side is at most 1024 px, encoded as JPEG.
enum UploadImage {
    static let defaultLongSide = 1024
    static let defaultQuality: CGFloat = 0.8

    /// Pixel size after scaling. Keeps the aspect ratio and never upscales.
    static func scaledSize(width: Int, height: Int, longSide: Int = UploadImage.defaultLongSide) -> (width: Int, height: Int) {
        let currentLongSide = max(width, height)
        guard currentLongSide > longSide, longSide > 0 else {
            return (width: width, height: height)
        }
        let scale = Double(longSide) / Double(currentLongSide)
        let scaledWidth = max(1, Int((Double(width) * scale).rounded()))
        let scaledHeight = max(1, Int((Double(height) * scale).rounded()))
        return (width: scaledWidth, height: scaledHeight)
    }

    /// - Returns: JPEG data, or nil if the image could not be drawn or encoded.
    static func jpegData(
        from image: CGImage,
        longSide: Int = UploadImage.defaultLongSide,
        quality: CGFloat = UploadImage.defaultQuality
    ) -> Data? {
        let size = scaledSize(width: image.width, height: image.height, longSide: longSide)
        guard size.width > 0, size.height > 0 else { return nil }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: size.width,
            height: size.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.interpolationQuality = .high
        // JPEG has no alpha; anything transparent ends up on white.
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(rect)
        context.draw(image, in: rect)

        guard let scaled = context.makeImage() else { return nil }
        return UIImage(cgImage: scaled).jpegData(compressionQuality: quality)
    }
}
