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
    let isSelected: Bool
    let isDragging: Bool
    let isSnappedUpright: Bool
    let onTap: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    @State private var decodedImage: UIImage?

    var body: some View {
        let baseSize = BoardCanvasMath.baseSize(aspectRatio: record.aspectRatio)
        let screenPoint = BoardCanvasMath.worldToScreen(
            CGPoint(x: transform.x, y: transform.y),
            viewport: viewport,
            viewportSize: viewportSize
        )
        let visualScale = CGFloat(transform.scale) * viewport.zoom * (isDragging ? 1.03 : 1.0)

        let itemCore = Group {
            if let image = decodedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(YumojiTheme.card)
            }
        }
        .frame(width: baseSize.width, height: baseSize.height)
        .shadow(
            color: YumojiTheme.shadow.opacity(isDragging ? 1.25 : 0.85),
            radius: isDragging ? 14 : 8,
            y: isDragging ? 9 : 4
        )
        .overlay {
            if isSelected {
                selectionFrame
            }
        }
        .scaleEffect(visualScale)
        .rotationEffect(.radians(transform.rotation))
        .position(screenPoint)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task(id: record.id) {
            if decodedImage == nil {
                decodedImage = StickerThumbnailCache.shared.thumbnail(for: record)
            }
        }

        if isSelected {
            itemCore
                .highPriorityGesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            onDragChanged(value.translation)
                        }
                        .onEnded { value in
                            onDragEnded(value.translation)
                        }
                )
        } else {
            itemCore
        }
    }

    private var selectionFrame: some View {
        let strokeColor = isSnappedUpright ? Color.green.opacity(0.85) : YumojiTheme.accent.opacity(0.9)
        let lineWidth = max(1.5, 2.0 / max(viewport.zoom * CGFloat(transform.scale), 0.35))
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    strokeColor,
                    style: StrokeStyle(lineWidth: lineWidth, dash: [6, 4])
                )
                .padding(-6)
        }
    }
}
