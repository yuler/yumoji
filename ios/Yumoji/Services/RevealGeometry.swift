import CoreGraphics

/// Where the sticker starts when it lifts off the photo, so it begins exactly
/// over the subject. Both views fit their image into the same `available` area,
/// centred, so everything here is relative to the centre of that area.
enum RevealGeometry {
    struct Start: Equatable {
        /// Scale of the sticker at its start, relative to its final size.
        var scale: CGFloat
        /// Offset of the sticker's centre from its final position, in points.
        var offset: CGSize
    }

    /// - Parameters:
    ///   - photo: Photo size in pixels.
    ///   - crop: Sticker canvas in photo pixels; may reach past the photo edge.
    ///   - available: Area both images are fitted into, in points.
    /// - Returns: nil when any size is empty.
    static func start(photo: CGSize, crop: PixelRect, available: CGSize) -> Start? {
        guard photo.width > 0, photo.height > 0,
              crop.width > 0, crop.height > 0,
              available.width > 0, available.height > 0
        else { return nil }

        let photoScale = min(available.width / photo.width, available.height / photo.height)
        let stickerScale = min(
            available.width / CGFloat(crop.width),
            available.height / CGFloat(crop.height)
        )

        let cropCenterX = CGFloat(crop.x) + CGFloat(crop.width) / 2
        let cropCenterY = CGFloat(crop.y) + CGFloat(crop.height) / 2
        return Start(
            scale: photoScale / stickerScale,
            offset: CGSize(
                width: (cropCenterX - photo.width / 2) * photoScale,
                height: (cropCenterY - photo.height / 2) * photoScale
            )
        )
    }
}
