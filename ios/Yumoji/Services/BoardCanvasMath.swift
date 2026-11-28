import CoreGraphics
import Foundation

struct BoardViewport: Equatable, Sendable {
    /// Pan offset in screen points relative to the canvas center.
    var offset: CGSize = .zero
    /// Global zoom factor of the canvas.
    var zoom: CGFloat = 1.0

    static let identity = BoardViewport(offset: .zero, zoom: 1.0)
}

struct BoardItemGeometry: Equatable, Sendable {
    let x: Double
    let y: Double
    let scale: Double
    let aspectRatio: Double
}

struct WorldPlacement: Equatable, Sendable {
    let x: Double
    let y: Double
    let rotation: Double
    let zIndex: Int
}

struct RotationSnapResult: Equatable, Sendable {
    let radians: Double
    let snapped: Bool
}

struct HandleTransformResult: Equatable, Sendable {
    let scale: Double
    let rotation: Double
    let snappedUpright: Bool
}

enum BoardZoomDirection: Sendable {
    case zoomIn
    case zoomOut
}

/// Pure geometry and transform utilities for the 2D zoomable sticker board.
enum BoardCanvasMath {
    static let baseStickerLongSide: CGFloat = 156
    static let minCanvasZoom: CGFloat = 0.3
    static let maxCanvasZoom: CGFloat = 2.5
    static let minStickerScale: Double = 0.35
    static let maxStickerScale: Double = 3.0
    static let defaultSnapThresholdDegrees: Double = 4.0
    static let zoomStepFactor: CGFloat = 1.25

    static func clampCanvasZoom(_ zoom: CGFloat) -> CGFloat {
        min(maxCanvasZoom, max(minCanvasZoom, zoom))
    }

    /// Steps canvas zoom in or out by a predictable factor for toolbar buttons and keyboard shortcuts.
    static func steppedCanvasZoom(from current: CGFloat, direction: BoardZoomDirection) -> CGFloat {
        let factor: CGFloat = direction == .zoomIn ? zoomStepFactor : (1.0 / zoomStepFactor)
        return clampCanvasZoom(current * factor)
    }

    /// Computes scale and rotation from dragging a single-pointer corner handle around `center`.
    static func handleTransform(
        center: CGPoint,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        baseScale: Double,
        baseRotation: Double,
        snapThresholdDegrees: Double = defaultSnapThresholdDegrees
    ) -> HandleTransformResult {
        let startDX = Double(startPoint.x - center.x)
        let startDY = Double(startPoint.y - center.y)
        let currentDX = Double(currentPoint.x - center.x)
        let currentDY = Double(currentPoint.y - center.y)

        let startDist = hypot(startDX, startDY)
        let currentDist = hypot(currentDX, currentDY)
        guard startDist > 4, currentDist > 4 else {
            return HandleTransformResult(
                scale: clampStickerScale(baseScale),
                rotation: baseRotation,
                snappedUpright: false
            )
        }

        let newScale = clampStickerScale(baseScale * (currentDist / startDist))
        let angleDelta = atan2(currentDY, currentDX) - atan2(startDY, startDX)
        let snap = snapRotation(baseRotation + angleDelta, thresholdDegrees: snapThresholdDegrees)
        return HandleTransformResult(
            scale: newScale,
            rotation: snap.radians,
            snappedUpright: snap.snapped
        )
    }

    static func clampStickerScale(_ scale: Double) -> Double {
        min(maxStickerScale, max(minStickerScale, scale))
    }

    /// Base unscaled sticker size in board world points.
    static func baseSize(aspectRatio: Double) -> CGSize {
        let clamped = max(0.25, min(4.0, aspectRatio))
        if clamped >= 1.0 {
            return CGSize(width: baseStickerLongSide, height: baseStickerLongSide / clamped)
        } else {
            return CGSize(width: baseStickerLongSide * clamped, height: baseStickerLongSide)
        }
    }

    /// Converts a world coordinate `(x, y)` to a screen position inside `viewportSize`.
    static func worldToScreen(
        _ worldPoint: CGPoint,
        viewport: BoardViewport,
        viewportSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: viewportSize.width / 2 + viewport.offset.width + worldPoint.x * viewport.zoom,
            y: viewportSize.height / 2 + viewport.offset.height + worldPoint.y * viewport.zoom
        )
    }

    /// Converts a screen position inside `viewportSize` to a world coordinate.
    static func screenToWorld(
        _ screenPoint: CGPoint,
        viewport: BoardViewport,
        viewportSize: CGSize
    ) -> CGPoint {
        let safeZoom = max(viewport.zoom, 0.01)
        return CGPoint(
            x: (screenPoint.x - viewportSize.width / 2 - viewport.offset.width) / safeZoom,
            y: (screenPoint.y - viewportSize.height / 2 - viewport.offset.height) / safeZoom
        )
    }

    /// Returns the world point currently at the center of the screen.
    static func visibleWorldCenter(viewport: BoardViewport) -> CGPoint {
        let safeZoom = max(viewport.zoom, 0.01)
        return CGPoint(
            x: -viewport.offset.width / safeZoom,
            y: -viewport.offset.height / safeZoom
        )
    }

    /// Zooms the canvas while keeping `anchor` (in screen points) pinned to the same world point.
    static func zoomedViewport(
        from base: BoardViewport,
        magnification: CGFloat,
        anchor: CGPoint,
        viewportSize: CGSize
    ) -> BoardViewport {
        let targetZoom = clampCanvasZoom(base.zoom * magnification)
        let worldAtAnchor = screenToWorld(anchor, viewport: base, viewportSize: viewportSize)
        let newOffsetX = anchor.x - viewportSize.width / 2 - worldAtAnchor.x * targetZoom
        let newOffsetY = anchor.y - viewportSize.height / 2 - worldAtAnchor.y * targetZoom
        return BoardViewport(
            offset: CGSize(width: newOffsetX, height: newOffsetY),
            zoom: targetZoom
        )
    }

    /// Computes a viewport that frames and centers all items inside `viewportSize`.
    static func fitAll(
        items: [BoardItemGeometry],
        viewportSize: CGSize,
        padding: CGFloat = 56,
        maxZoom: CGFloat = 1.0
    ) -> BoardViewport {
        guard !items.isEmpty, viewportSize.width > 1, viewportSize.height > 1 else {
            return .identity
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for item in items {
            let size = baseSize(aspectRatio: item.aspectRatio)
            let halfW = size.width * CGFloat(item.scale) / 2
            let halfH = size.height * CGFloat(item.scale) / 2
            minX = min(minX, CGFloat(item.x) - halfW)
            maxX = max(maxX, CGFloat(item.x) + halfW)
            minY = min(minY, CGFloat(item.y) - halfH)
            maxY = max(maxY, CGFloat(item.y) + halfH)
        }

        let contentW = max(maxX - minX, 1)
        let contentH = max(maxY - minY, 1)
        let availW = max(viewportSize.width - padding * 2, 80)
        let availH = max(viewportSize.height - padding * 2, 80)
        let fitZoom = min(availW / contentW, availH / contentH)
        let clampedZoom = clampCanvasZoom(min(fitZoom, maxZoom))

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        return BoardViewport(
            offset: CGSize(width: -centerX * clampedZoom, height: -centerY * clampedZoom),
            zoom: clampedZoom
        )
    }

    /// Computes a viewport centered on a specific world point at `zoom`.
    static func focus(on worldPoint: CGPoint, zoom: CGFloat = 1.0) -> BoardViewport {
        let clamped = clampCanvasZoom(zoom)
        return BoardViewport(
            offset: CGSize(width: -worldPoint.x * clamped, height: -worldPoint.y * clamped),
            zoom: clamped
        )
    }

    /// Applies gentle magnetic snapping near 0 radians (upright orientation).
    static func snapRotation(
        _ radians: Double,
        thresholdDegrees: Double = defaultSnapThresholdDegrees
    ) -> RotationSnapResult {
        let twoPi = Double.pi * 2
        var normalized = radians.truncatingRemainder(dividingBy: twoPi)
        if normalized > Double.pi {
            normalized -= twoPi
        } else if normalized < -Double.pi {
            normalized += twoPi
        }
        let threshold = thresholdDegrees * Double.pi / 180.0
        if abs(normalized) <= threshold {
            return RotationSnapResult(radians: 0, snapped: true)
        }
        return RotationSnapResult(radians: normalized, snapped: false)
    }

    /// Computes a staggered, non-overlapping initial world placement around `anchor`.
    static func nextWorldPlacement(
        existingCount: Int,
        maxZIndex: Int,
        around anchor: CGPoint = .zero
    ) -> WorldPlacement {
        let offsets: [(Double, Double, Double)] = [
            (0, 0, -0.05),
            (-76, 42, 0.08),
            (78, -36, -0.09),
            (-64, -74, 0.06),
            (72, 68, -0.07),
            (-118, -6, 0.10),
            (116, 12, -0.08),
            (0, 108, 0.05),
            (0, -104, -0.06)
        ]
        let ring = existingCount / offsets.count
        let slot = existingCount % offsets.count
        let ringShift = Double(ring) * 34.0
        let (dx, dy, angle) = offsets[slot]
        return WorldPlacement(
            x: Double(anchor.x) + dx + (ring % 2 == 0 ? ringShift : -ringShift),
            y: Double(anchor.y) + dy + ringShift * 0.75,
            rotation: angle,
            zIndex: maxZIndex + 1
        )
    }

    /// Migrates a legacy normalized-X / top-down-Y record coordinate into centered world points.
    static func migrateLegacyCoordinate(normalizedX: Double, legacyY: Double) -> CGPoint {
        let referenceWidth: Double = 390.0
        let referenceCenterY: Double = 260.0
        return CGPoint(
            x: (normalizedX - 0.5) * referenceWidth,
            y: legacyY - referenceCenterY
        )
    }
}
