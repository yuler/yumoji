import SwiftUI
import UIKit

/// Editable world-space transform for a sticker on the 2D board.
struct DraftStickerTransform: Equatable {
    var x: Double
    var y: Double
    var scale: Double
    var rotation: Double

    init(x: Double, y: Double, scale: Double, rotation: Double) {
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
    }

    init(placement: BoardItemPlacement) {
        self.x = placement.x
        self.y = placement.y
        self.scale = placement.scale
        self.rotation = placement.rotation
    }
}

/// Renders one sticker on the 2D zoomable canvas.
/// Unselected stickers only accept tap-to-select so canvas pan/zoom never fights them;
/// once selected, single-finger dragging on the sticker moves it in world space.
@MainActor
struct BoardStickerItemView: View {
    let record: StickerRecord
    let transform: DraftStickerTransform
    let viewport: BoardViewport
    let viewportSize: CGSize
    let canvasCoordinateSpace: String
    let isSelected: Bool
    let isDragging: Bool
    let isSnappedUpright: Bool
    let onTap: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    @State private var decodedImage: UIImage?

    var body: some View {
        let baseSize = BoardCanvasMath.baseSize(aspectRatio: record.aspectRatio)
        let visualScale = CGFloat(transform.scale) * viewport.zoom * (isDragging ? 1.03 : 1.0)
        let displaySize = CGSize(
            width: max(1, baseSize.width * visualScale),
            height: max(1, baseSize.height * visualScale)
        )
        let screenPoint = BoardCanvasMath.worldToScreen(
            CGPoint(x: transform.x, y: transform.y),
            viewport: viewport,
            viewportSize: viewportSize
        )

        Group {
            if let image = decodedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(YumojiTheme.card)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .shadow(
            color: YumojiTheme.shadow.opacity(isDragging ? 1.25 : 0.85),
            radius: isDragging ? 14 : 8,
            y: isDragging ? 9 : 4
        )
        .overlay {
            if isSelected {
                selectionFrame(for: displaySize)
            }
        }
        // Keep hit-testing and gestures scoped to the sticker's own bounds BEFORE `.position`,
        // because `.position` expands the layout frame to the full canvas.
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named(canvasCoordinateSpace))
                .onChanged { value in
                    onDragChanged(value.translation)
                }
                .onEnded { value in
                    onDragEnded(value.translation)
                },
            including: isSelected ? .all : .subviews
        )
        .rotationEffect(.radians(transform.rotation))
        .position(screenPoint)
        .task(id: record.id) {
            if decodedImage == nil {
                decodedImage = StickerThumbnailCache.shared.thumbnail(for: record)
            }
        }
    }

    private func selectionFrame(for size: CGSize) -> some View {
        let strokeColor = isSnappedUpright ? Color.green.opacity(0.85) : YumojiTheme.accent.opacity(0.9)
        let cornerRadius = min(16, max(8, min(size.width, size.height) * 0.14))
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                strokeColor,
                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
            )
            .padding(-6)
            .allowsHitTesting(false)
    }
}
