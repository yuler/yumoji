import SwiftUI
import UIKit

/// One interactive sticker placed on the freeform board: supports drag,
/// pinch-to-scale, rotate, and tap-to-select with persisted transform state.
@MainActor
struct BoardStickerItemView: View {
    let record: StickerRecord
    let boardWidth: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onCommitTransform: (_ x: Double, _ y: Double, _ scale: Double, _ rotation: Double) -> Void

    static let baseLongSide: CGFloat = 156
    static let minScale: Double = 0.45
    static let maxScale: Double = 2.4

    @State private var decodedImage: UIImage?
    @State private var dragDelta: CGSize = .zero
    @State private var isDragging = false
    @State private var liveScaleFactor: Double = 1.0
    @State private var liveRotationDelta: Double = 0.0

    var body: some View {
        let size = baseSize
        let currentScale = clampedScale(record.scale * liveScaleFactor)
        let currentRotation = record.rotation + liveRotationDelta
        let posX = CGFloat(record.x) * boardWidth + dragDelta.width
        let posY = CGFloat(record.y) + dragDelta.height

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
        .frame(width: size.width, height: size.height)
        .shadow(
            color: YumojiTheme.shadow.opacity(isDragging ? 1.25 : 0.9),
            radius: isDragging ? 14 : 8,
            y: isDragging ? 9 : 4
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        YumojiTheme.accent.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .padding(-6)
            }
        }
        .scaleEffect(currentScale * (isDragging ? 1.04 : 1.0))
        .rotationEffect(.radians(currentRotation))
        .position(x: posX, y: posY)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .highPriorityGesture(dragGesture)
        .simultaneousGesture(transformGesture)
        .task(id: record.id) {
            decodeThumbnail()
        }
    }

    private var baseSize: CGSize {
        let aspect = max(0.25, min(4.0, record.aspectRatio))
        if aspect >= 1.0 {
            return CGSize(width: Self.baseLongSide, height: Self.baseLongSide / aspect)
        } else {
            return CGSize(width: Self.baseLongSide * aspect, height: Self.baseLongSide)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    onSelect()
                }
                dragDelta = value.translation
            }
            .onEnded { value in
                let safeWidth = max(boardWidth, 1)
                let newX = min(0.94, max(0.06, record.x + Double(value.translation.width / safeWidth)))
                let newY = max(84.0, record.y + Double(value.translation.height))
                dragDelta = .zero
                isDragging = false
                onCommitTransform(newX, newY, record.scale, record.rotation)
            }
    }

    private var transformGesture: some Gesture {
        MagnifyGesture()
            .simultaneously(with: RotateGesture())
            .onChanged { value in
                if let mag = value.first {
                    liveScaleFactor = Double(mag.magnification)
                }
                if let rot = value.second {
                    liveRotationDelta = rot.rotation.radians
                }
            }
            .onEnded { value in
                let finalMag = value.first.map { Double($0.magnification) } ?? liveScaleFactor
                let finalScale = clampedScale(record.scale * finalMag)
                let finalRotation = record.rotation + (value.second?.rotation.radians ?? liveRotationDelta)
                liveScaleFactor = 1.0
                liveRotationDelta = 0.0
                onCommitTransform(record.x, record.y, finalScale, finalRotation)
            }
    }

    private func clampedScale(_ value: Double) -> Double {
        min(Self.maxScale, max(Self.minScale, value))
    }

    private func decodeThumbnail() {
        guard decodedImage == nil else { return }
        if let thumbData = record.thumbnailData, let img = UIImage(data: thumbData) {
            decodedImage = img
        } else if let pngData = record.asset?.pngData, let img = UIImage(data: pngData) {
            decodedImage = img
        }
    }
}
