import CoreGraphics
import CoreImage
import CoreVideo
import Vision

/// Subject lifting with Vision's foreground instance mask (iOS 17+).
/// Runs on real devices only; the simulator throws from `perform`.
struct VisionSubjectLifter: SubjectLifting {
    func liftSubject(from image: CGImage) async throws -> SubjectMask {
        try await Task.detached(priority: .userInitiated) {
            try VisionSubjectLifter.lift(image)
        }.value
    }

    private static func lift(_ image: CGImage) throws -> SubjectMask {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw SubjectLiftingError.noSubject
        }
        let instances = observation.allInstances
        guard !instances.isEmpty else {
            throw SubjectLiftingError.noSubject
        }

        let buffer = try observation.generateScaledMaskForImage(forInstances: instances, from: handler)
        guard let mask = readMask(buffer) ?? renderMask(buffer), mask.bounds != nil else {
            throw SubjectLiftingError.noSubject
        }
        return mask
    }

    /// Reads the mask bytes straight out of the pixel buffer, which is expected
    /// to be one-component 32-bit float in 0...1. Returns nil for other formats.
    private static func readMask(_ buffer: CVPixelBuffer) -> SubjectMask? {
        let format = CVPixelBufferGetPixelFormatType(buffer)
        guard format == kCVPixelFormatType_OneComponent32Float || format == kCVPixelFormatType_OneComponent8 else {
            return nil
        }

        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        guard width > 0, height > 0, let base = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            let row = base + y * rowBytes
            if format == kCVPixelFormatType_OneComponent32Float {
                let values = row.assumingMemoryBound(to: Float32.self)
                for x in 0..<width {
                    let value = values[x]
                    if value.isFinite {
                        pixels[y * width + x] = UInt8(max(0, min(255, (value * 255).rounded())))
                    }
                }
            } else {
                let values = row.assumingMemoryBound(to: UInt8.self)
                for x in 0..<width {
                    pixels[y * width + x] = values[x]
                }
            }
        }
        return SubjectMask(width: width, height: height, pixels: pixels)
    }

    /// Fallback for any other pixel format: let Core Image render the buffer
    /// and take the red channel, which is where a one-component buffer lands.
    private static func renderMask(_ buffer: CVPixelBuffer) -> SubjectMask? {
        let source = CIImage(cvPixelBuffer: buffer)
        guard let rendered = CIContext().createCGImage(source, from: source.extent) else {
            return nil
        }
        let width = rendered.width
        let height = rendered.height
        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { return nil }
        context.draw(rendered, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }

        let bytes = data.assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 0, count: width * height)
        for index in 0..<(width * height) {
            pixels[index] = bytes[index * 4]
        }
        return SubjectMask(width: width, height: height, pixels: pixels)
    }
}
