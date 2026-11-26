import CoreGraphics

/// Sticker plus the outline and the leftover-paper mask, built off the main thread.
/// `CGImage` crosses the task boundary here the same way the sticker render already did.
struct RenderedCutout: @unchecked Sendable {
    var sticker: CGImage?
    var contour: [CGPoint]
    var outside: OutsideMask.Bitmap?

    static func make(image: CGImage, mask: SubjectMask, style: StickerStyle) -> RenderedCutout {
        RenderedCutout(
            sticker: StickerCompositor.makeSticker(image: image, mask: mask, style: style),
            contour: ContourPath.trace(width: mask.width, height: mask.height, pixels: mask.pixels),
            outside: OutsideMask.bitmap(width: mask.width, height: mask.height, pixels: mask.pixels)
        )
    }
}
