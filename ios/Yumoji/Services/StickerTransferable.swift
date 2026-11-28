import CoreTransferable
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Transparent PNG payload used when dragging a sticker out to another iPad/iOS app.
struct StickerDragItem: Transferable {
    let pngData: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.pngData
        }
    }
}

/// Incoming image bytes dropped onto Yumoji from Photos, Safari, Files, or Split View.
struct DroppedImageItem: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            DroppedImageItem(data: data)
        }
    }
}

/// Reusable drop overlay accepting images from other apps and forwarding bytes to the cutout flow.
private struct ImageDropTargetModifier: ViewModifier {
    let onImageData: (Data) -> Void

    @Environment(LanguageManager.self) private var lang
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isTargeted {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(YumojiTheme.accent.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(
                                        YumojiTheme.accent,
                                        style: StrokeStyle(lineWidth: 3, dash: [10, 6])
                                    )
                            )
                            .padding(14)

                        Label(lang.t("drop.hint"), systemImage: "photo.badge.plus")
                            .font(YumojiTheme.rounded(16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(YumojiTheme.accent, in: Capsule())
                            .shadow(color: YumojiTheme.shadow.opacity(0.8), radius: 12, y: 4)
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.16), value: isTargeted)
            .dropDestination(for: DroppedImageItem.self) { items, _ in
                guard let first = items.first, !first.data.isEmpty else { return false }
                onImageData(first.data)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}

extension View {
    func yumojiImageDropTarget(onImageData: @escaping (Data) -> Void) -> some View {
        modifier(ImageDropTargetModifier(onImageData: onImageData))
    }
}
