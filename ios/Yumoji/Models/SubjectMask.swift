import CoreGraphics
import Foundation

/// Integer rectangle in pixel coordinates, origin at the top-left.
struct PixelRect: Equatable, Sendable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int
}

/// Subject mask for a photo: one byte per pixel, rows top to bottom,
/// 0 = background, 255 = subject. Same pixel size as the photo it came from.
struct SubjectMask: Sendable {
    /// Pixels at or above this value count as subject when measuring bounds.
    static let threshold: UInt8 = 128

    let width: Int
    let height: Int
    let pixels: [UInt8]
    /// Bounding box of the subject, nil when the mask is empty.
    let bounds: PixelRect?

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(width > 0 && height > 0, "SubjectMask needs a positive size")
        precondition(pixels.count == width * height, "SubjectMask pixel count mismatch")
        self.width = width
        self.height = height
        self.pixels = pixels
        self.bounds = SubjectMask.findBounds(width: width, height: height, pixels: pixels)
    }

    /// Mask bytes inside `rect`, which may reach outside the mask; outside is 0.
    func croppedPixels(to rect: PixelRect) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: rect.width * rect.height)
        let startX = max(rect.x, 0)
        let endX = min(rect.x + rect.width, width)
        let startY = max(rect.y, 0)
        let endY = min(rect.y + rect.height, height)
        guard startX < endX, startY < endY else { return output }

        let count = endX - startX
        for y in startY..<endY {
            let source = y * width + startX
            let destination = (y - rect.y) * rect.width + (startX - rect.x)
            output.replaceSubrange(
                destination..<(destination + count),
                with: pixels[source..<(source + count)]
            )
        }
        return output
    }

    /// Wraps mask bytes as a DeviceGray image without alpha, the form
    /// `CGContext.clip(to:mask:)` accepts as an alpha mask.
    static func grayImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage? {
        guard width > 0, height > 0, pixels.count == width * height,
              let provider = CGDataProvider(data: Data(pixels) as CFData)
        else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func findBounds(width: Int, height: Int, pixels: [UInt8]) -> PixelRect? {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        let limit = SubjectMask.threshold
        pixels.withUnsafeBufferPointer { buffer in
            for y in 0..<height {
                let rowStart = y * width
                for x in 0..<width where buffer[rowStart + x] >= limit {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= 0 else { return nil }
        return PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
