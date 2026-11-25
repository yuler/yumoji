import CoreGraphics
import CoreImage

/// Turns a photo plus its subject mask into a sticker: the subject on a white
/// border, cropped tight, transparent everywhere else. No Vision in here.
enum StickerCompositor {
    private static let ciContext = CIContext()

    /// - Parameters:
    ///   - image: The photo, upright. Stretched to the mask's pixel size if they differ.
    ///   - mask: Subject mask for `image`.
    ///   - style: Border, smoothing and margin.
    /// - Returns: RGBA sticker with a transparent background, or nil if the mask is empty.
    static func makeSticker(
        image: CGImage,
        mask: SubjectMask,
        style: StickerStyle = StickerStyle()
    ) -> CGImage? {
        guard let subject = mask.bounds else { return nil }

        let longSide = max(subject.width, subject.height)
        let border = style.borderWidth(subjectLongSide: longSide)
        let margin = style.marginWidth(subjectLongSide: longSide)
        // One spare pixel keeps the antialiased border edge off the canvas edge.
        let pad = Int((border + margin).rounded(.up)) + 1
        let crop = PixelRect(
            x: subject.x - pad,
            y: subject.y - pad,
            width: subject.width + 2 * pad,
            height: subject.height + 2 * pad
        )

        let subjectPixels = mask.croppedPixels(to: crop)
        guard let subjectMask = SubjectMask.grayImage(
            width: crop.width,
            height: crop.height,
            pixels: subjectPixels
        ) else { return nil }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: crop.width,
            height: crop.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let canvas = CGRect(x: 0, y: 0, width: crop.width, height: crop.height)
        context.clear(canvas)
        context.interpolationQuality = .high

        if border >= 0.5 {
            guard let borderMask = makeBorderMask(
                from: subjectMask,
                radius: border,
                sigma: max(0, style.edgeSmoothing) * border
            ) else { return nil }
            context.saveGState()
            context.clip(to: canvas, mask: borderMask)
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(canvas)
            context.restoreGState()
        }

        // Core Graphics has its origin at the bottom-left; `crop` counts from the top.
        let photoRect = CGRect(
            x: -crop.x,
            y: crop.height + crop.y - mask.height,
            width: mask.width,
            height: mask.height
        )
        context.saveGState()
        context.clip(to: canvas, mask: subjectMask)
        context.draw(image, in: photoRect)
        context.restoreGState()

        return context.makeImage()
    }

    /// Grows the mask by `radius` pixels, then blurs and re-sharpens the edge so
    /// the outline is rounded and antialiased instead of following every jag.
    private static func makeBorderMask(from maskImage: CGImage, radius: Double, sigma: Double) -> CGImage? {
        let source = CIImage(cgImage: maskImage)
        let extent = source.extent

        var output = source
            .clampedToExtent()
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius])

        if sigma >= 0.5 {
            // Blur softens the outline; the steep ramp around 0.5 brings the edge
            // back to about 1.5 px wide without moving it.
            let gain = CGFloat(max(1.0, 1.7 * sigma))
            let bias = 0.5 - 0.5 * gain
            output = output
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: sigma])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0),
                ])
        }

        guard let rendered = ciContext.createCGImage(output.cropped(to: extent), from: extent) else {
            return nil
        }
        return grayscale(rendered)
    }

    /// Redraws an image as DeviceGray without alpha so it can be used as a clip mask.
    private static func grayscale(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
