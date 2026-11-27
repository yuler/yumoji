import Foundation
import UIKit

/// In-memory cache of decoded sticker thumbnails so grid pinches and board redraws
/// do not repeatedly decode PNG bytes on the main thread.
@MainActor
final class StickerThumbnailCache {
    static let shared = StickerThumbnailCache()

    private let cache: NSCache<NSUUID, UIImage> = {
        let store = NSCache<NSUUID, UIImage>()
        store.countLimit = 400
        return store
    }()

    func thumbnail(for record: StickerRecord) -> UIImage? {
        let key = record.id as NSUUID
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if let data = record.thumbnailData, let image = UIImage(data: data) {
            cache.setObject(image, forKey: key)
            return image
        }
        if let data = record.asset?.pngData, let image = UIImage(data: data) {
            cache.setObject(image, forKey: key)
            return image
        }
        return nil
    }

    func fullResolutionImage(for record: StickerRecord) -> UIImage? {
        if let data = record.asset?.pngData, let image = UIImage(data: data) {
            return image
        }
        return thumbnail(for: record)
    }

    func invalidate(_ id: UUID) {
        cache.removeObject(forKey: id as NSUUID)
    }

    func clear() {
        cache.removeAllObjects()
    }
}
