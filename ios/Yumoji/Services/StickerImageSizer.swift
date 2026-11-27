import CoreGraphics
import Foundation

/// Prepared PNG payloads ready to write to SwiftData.
struct PreparedStickerImages: Sendable {
    let pngData: Data
    let thumbnailData: Data
    let pixelWidth: Int
    let pixelHeight: Int

    var byteSize: Int64 {
        Int64(pngData.count + thumbnailData.count)
    }
}

/// Resizes transparent sticker images for storage (1024px full + 320px thumbnail).
enum StickerImageSizer {
    static let maxSavedLongSide = 1024
    static let thumbnailLongSide = 320

    static func scaledSize(width: Int, height: Int, maxLongSide: Int) -> (width: Int, height: Int) {
        guard width > 0, height > 0, maxLongSide > 0 else { return (width, height) }
        let longSide = max(width, height)
        guard longSide > maxLongSide else { return (width, height) }
        let ratio = Double(maxLongSide) / Double(longSide)
        return (
            width: max(1, Int((Double(width) * ratio).rounded())),
            height: max(1, Int((Double(height) * ratio).rounded()))
        )
    }

    static func scaled(_ image: CGImage, maxLongSide: Int) -> CGImage? {
        let target = scaledSize(width: image.width, height: image.height, maxLongSide: maxLongSide)
        if target.width == image.width && target.height == image.height {
            return image
        }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: target.width,
            height: target.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: target.width, height: target.height))
        return context.makeImage()
    }

    static func prepareForStorage(_ image: CGImage) -> PreparedStickerImages? {
        guard let full = scaled(image, maxLongSide: maxSavedLongSide),
              let thumb = scaled(full, maxLongSide: thumbnailLongSide),
              let pngData = StickerPNG.data(from: full),
              let thumbnailData = StickerPNG.data(from: thumb)
        else {
            return nil
        }
        return PreparedStickerImages(
            pngData: pngData,
            thumbnailData: thumbnailData,
            pixelWidth: full.width,
            pixelHeight: full.height
        )
    }
}
