import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Scrollable freeform sticker notebook where collected stickers can be moved,
/// scaled, rotated, reordered, exported with backgrounds, or deleted.
@MainActor
struct StickerBoardView: View {
    let stickers: [StickerRecord]
    @Binding var selectedStickerID: UUID?
    @Binding var preferredDropY: Double
    let cameraAvailable: Bool
    let onOpenCamera: () -> Void
    let onPhoto: (PhotoInput) -> Void
    let onExportSticker: (UIImage) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lang

    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingDelete: StickerRecord?

    private var selectedSticker: StickerRecord? {
        guard let selectedStickerID else { return nil }
        return stickers.first { $0.id == selectedStickerID }
    }

    var body: some View {
        GeometryReader { outer in
            let viewportHeight = max(outer.size.height, 400)
            let boardWidth = max(outer.size.width, 320)
            let canvasHeight = max(
                viewportHeight + 120,
                (stickers.map(\.y).max() ?? 0) + 320
            )

            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        DotGridBackground()
                            .frame(width: boardWidth, height: canvasHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedStickerID = nil
                            }

                        GeometryReader { scrollProxy in
                            let minY = scrollProxy.frame(in: .named("StickerBoardScroll")).minY
                            Color.clear
                                .preference(
                                    key: BoardScrollOffsetKey.self,
                                    value: max(0, -minY)
                                )
                        }
                        .frame(height: 1)

                        ForEach(stickers) { record in
                            BoardStickerItemView(
                                record: record,
                                boardWidth: boardWidth,
                                isSelected: record.id == selectedStickerID,
                                onSelect: {
                                    selectAndRaise(record)
                                },
                                onCommitTransform: { x, y, scale, rotation in
                                    commitTransform(
                                        for: record,
                                        x: x,
                                        y: y,
                                        scale: scale,
                                        rotation: rotation
                                    )
                                }
                            )
                            .zIndex(Double(record.zIndex))
                        }
                    }
                    .frame(width: boardWidth, height: canvasHeight)
                }
                .coordinateSpace(name: "StickerBoardScroll")
                .onPreferenceChange(BoardScrollOffsetKey.self) { offsetY in
                    preferredDropY = Double(offsetY + viewportHeight * 0.42)
                }

                VStack(spacing: 10) {
                    if let active = selectedSticker {
                        selectedActionBar(for: active)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    bottomDock
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: selectedStickerID)
            }
        }
        .background(YumojiTheme.cream.ignoresSafeArea())
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            pickerItem = nil
            onPhoto(.library(newItem))
        }
        .confirmationDialog(
            lang.t("board.delete.confirm.title"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(lang.t("board.delete.confirm.action"), role: .destructive) {
                if let target = pendingDelete {
                    deleteSticker(target)
                }
                pendingDelete = nil
            }
            Button(lang.t("board.delete.confirm.cancel"), role: .cancel) {
                pendingDelete = nil
            }
        }
    }

    // MARK: - Controls

    private func selectedActionBar(for record: StickerRecord) -> some View {
        HStack(spacing: 6) {
            actionChip(lang.t("board.action.bring_front"), systemImage: "square.3.layers.3d.top.filled") {
                bringToFront(record)
            }

            actionChip(lang.t("board.action.export"), systemImage: "square.and.arrow.up") {
                if let image = fullResolutionImage(for: record) {
                    onExportSticker(image)
                }
            }

            actionChip(lang.t("board.action.delete"), systemImage: "trash", destructive: true) {
                pendingDelete = record
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(YumojiTheme.card.opacity(0.96), in: Capsule())
        .overlay(
            Capsule().strokeBorder(YumojiTheme.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: YumojiTheme.shadow.opacity(0.7), radius: 10, y: 4)
    }

    private func actionChip(
        _ title: String,
        systemImage: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(YumojiTheme.rounded(13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(destructive ? Color.red : YumojiTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                destructive ? Color.red.opacity(0.1) : YumojiTheme.surfaceSecondary.opacity(0.8),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private var bottomDock: some View {
        let pickLabel = lang.t("home.pick_from_library")
        return HStack(spacing: 10) {
            Button {
                onOpenCamera()
            } label: {
                Label(lang.t("home.take_photo"), systemImage: "camera.fill")
                    .font(YumojiTheme.rounded(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(YumojiTheme.accent, in: Capsule())
            }
            .disabled(!cameraAvailable)
            .opacity(cameraAvailable ? 1 : 0.45)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(pickLabel, systemImage: "photo.on.rectangle")
                    .font(YumojiTheme.rounded(15, weight: .semibold))
                    .foregroundStyle(YumojiTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(YumojiTheme.card, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(YumojiTheme.ink.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .shadow(color: YumojiTheme.shadow.opacity(0.65), radius: 10, y: 4)
    }

    // MARK: - Persistence Actions

    private func selectAndRaise(_ record: StickerRecord) {
        selectedStickerID = record.id
        bringToFront(record)
    }

    private func bringToFront(_ record: StickerRecord) {
        let maxZ = stickers.map(\.zIndex).max() ?? 0
        guard record.zIndex < maxZ else { return }
        record.zIndex = maxZ + 1
        try? modelContext.save()
    }

    private func commitTransform(
        for record: StickerRecord,
        x: Double,
        y: Double,
        scale: Double,
        rotation: Double
    ) {
        record.x = x
        record.y = y
        record.scale = scale
        record.rotation = rotation
        let maxZ = stickers.map(\.zIndex).max() ?? 0
        if record.zIndex < maxZ {
            record.zIndex = maxZ + 1
        }
        try? modelContext.save()
    }

    private func deleteSticker(_ record: StickerRecord) {
        if selectedStickerID == record.id {
            selectedStickerID = nil
        }
        try? StickerStorage.delete(record, in: modelContext)
    }

    private func fullResolutionImage(for record: StickerRecord) -> UIImage? {
        if let pngData = record.asset?.pngData, let image = UIImage(data: pngData) {
            return image
        }
        if let thumbData = record.thumbnailData, let image = UIImage(data: thumbData) {
            return image
        }
        return nil
    }
}

private struct BoardScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Subtle bullet-journal dot grid over the warm cream canvas.
private struct DotGridBackground: View {
    var spacing: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(YumojiTheme.cream))
            let dotColor = YumojiTheme.inkSoft.opacity(0.22)
            let dotSize: CGFloat = 2.2
            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing
                while x < size.width {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
