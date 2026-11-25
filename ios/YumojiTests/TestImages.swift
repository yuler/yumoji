import CoreGraphics
import Foundation
@testable import Yumoji

struct RGB: Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

struct RGBA: Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
}

/// Synthetic inputs. All coordinates count from the top-left, like image rows in memory.
enum TestImages {
    /// Opaque sRGB image; `color` is asked for every pixel.
    static func image(width: Int, height: Int, color: (_ x: Int, _ y: Int) -> RGB) -> CGImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let pixel = color(x, y)
                let index = (y * width + x) * 4
                bytes[index] = pixel.r
                bytes[index + 1] = pixel.g
                bytes[index + 2] = pixel.b
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    static func solid(width: Int, height: Int, color: RGB) -> CGImage {
        image(width: width, height: height) { _, _ in color }
    }

    /// Mask with a filled circle as the subject.
    static func circleMask(width: Int, height: Int, centerX: Int, centerY: Int, radius: Int) -> SubjectMask {
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy <= radius * radius {
                    pixels[y * width + x] = 255
                }
            }
        }
        return SubjectMask(width: width, height: height, pixels: pixels)
    }
}

/// Reads pixels back out of a `CGImage` as sRGB RGBA, rows top to bottom.
struct PixelReader {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(_ image: CGImage) {
        let pixelWidth = image.width
        let pixelHeight = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: pixelWidth,
                  height: pixelHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: pixelWidth * 4,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        let rect = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        context.clear(rect)
        context.draw(image, in: rect)
        guard let data = context.data else { return nil }

        let pointer = data.assumingMemoryBound(to: UInt8.self)
        self.width = pixelWidth
        self.height = pixelHeight
        self.bytes = Array(UnsafeBufferPointer(start: pointer, count: pixelWidth * pixelHeight * 4))
    }

    func pixel(x: Int, y: Int) -> RGBA {
        let index = (y * width + x) * 4
        return RGBA(r: bytes[index], g: bytes[index + 1], b: bytes[index + 2], a: bytes[index + 3])
    }
}
