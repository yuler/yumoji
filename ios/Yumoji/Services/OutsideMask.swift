import CoreGraphics
import Foundation

/// Alpha image of a photo with the subject punched out, so the leftover paper
/// can fall away while the cut piece stays behind as the sticker.
enum OutsideMask {
    struct Bitmap: Sendable, Equatable {
        var width: Int
        var height: Int
        /// Premultiplied-last RGBA. Opaque outside the subject, clear on it.
        var rgba: [UInt8]

        func cgImage() -> CGImage? {
            guard width > 0, height > 0, rgba.count == width * height * 4,
                  let provider = CGDataProvider(data: Data(rgba) as CFData),
                  let space = CGColorSpace(name: CGColorSpace.sRGB)
            else { return nil }
            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        }
    }

    static func bitmap(
        width: Int,
        height: Int,
        pixels: [UInt8],
        threshold: UInt8 = SubjectMask.threshold,
        maxSide: Int = 320
    ) -> Bitmap? {
        guard width > 0, height > 0, pixels.count == width * height, maxSide > 0 else { return nil }

        let scale = max(1, Int((Double(max(width, height)) / Double(maxSide)).rounded(.up)))
        let columns = (width + scale - 1) / scale
        let rows = (height + scale - 1) / scale
        var rgba = [UInt8](repeating: 255, count: columns * rows * 4)
        for row in 0..<rows {
            for column in 0..<columns {
                let x = min(width - 1, column * scale + scale / 2)
                let y = min(height - 1, row * scale + scale / 2)
                guard pixels[y * width + x] >= threshold else { continue }
                let index = (row * columns + column) * 4
                rgba[index] = 0
                rgba[index + 1] = 0
                rgba[index + 2] = 0
                rgba[index + 3] = 0
            }
        }
        return Bitmap(width: columns, height: rows, rgba: rgba)
    }
}
