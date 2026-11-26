import CoreGraphics

/// Size of the photo on the result screen: as wide as the content column,
/// as tall as the photo's aspect ratio, and never taller than `maxHeight`.
enum StageLayout {
    static let maxHeight: CGFloat = 480

    static func frame(image: CGSize, containerWidth: CGFloat, maxHeight: CGFloat = StageLayout.maxHeight) -> CGSize {
        let width = max(containerWidth, 0)
        guard image.width > 0, image.height > 0, width > 0 else {
            return CGSize(width: width, height: 0)
        }
        let natural = width * image.height / image.width
        return CGSize(width: width, height: min(natural, maxHeight))
    }

    /// Where a `scaledToFit` image actually draws inside `frame`.
    static func fittedRect(image: CGSize, frame: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0, frame.width > 0, frame.height > 0 else {
            return .zero
        }
        let scale = min(frame.width / image.width, frame.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: (frame.width - size.width) / 2,
            y: (frame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// The crop, in the same space as `fitted`, where `image` is the photo.
    /// Zero when the photo has not been given a frame yet.
    static func cropRect(_ crop: PixelRect, image: CGSize, fitted: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0,
              crop.width > 0, crop.height > 0,
              fitted.width > 0, fitted.height > 0
        else { return .zero }
        return CGRect(
            x: fitted.minX + CGFloat(crop.x) / image.width * fitted.width,
            y: fitted.minY + CGFloat(crop.y) / image.height * fitted.height,
            width: CGFloat(crop.width) / image.width * fitted.width,
            height: CGFloat(crop.height) / image.height * fitted.height
        )
    }

    /// Maps a point in image pixels onto `fitted`.
    static func map(_ point: CGPoint, image: CGSize, fitted: CGRect) -> CGPoint {
        guard image.width > 0, image.height > 0 else { return fitted.origin }
        return CGPoint(
            x: fitted.minX + point.x / image.width * fitted.width,
            y: fitted.minY + point.y / image.height * fitted.height
        )
    }
}
