import SwiftUI

/// Floating controls and infinite dot-grid background for `StickerBoardView`.
@MainActor
struct BoardSelectedActionBar: View {
    let onPin: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    let onPlace: () -> Void

    @Environment(LanguageManager.self) private var lang

    var body: some View {
        HStack(spacing: 6) {
            actionChip(lang.t("board.action.pin"), systemImage: "pin.fill", action: onPin)
            actionChip(lang.t("board.action.export_short"), systemImage: "square.and.arrow.up", action: onExport)
            actionChip(lang.t("board.action.delete"), systemImage: "trash", destructive: true, action: onDelete)
            actionChip(lang.t("board.action.place"), systemImage: "checkmark", prominent: true, action: onPlace)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(YumojiTheme.card.opacity(0.96), in: Capsule())
        .overlay(
            Capsule().strokeBorder(YumojiTheme.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: YumojiTheme.shadow.opacity(0.75), radius: 12, y: 4)
    }

    private func actionChip(
        _ title: String,
        systemImage: String,
        destructive: Bool = false,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(YumojiTheme.rounded(12.5, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(
                prominent ? Color.white : (destructive ? Color.red : YumojiTheme.ink)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                prominent
                    ? YumojiTheme.accent
                    : (destructive ? Color.red.opacity(0.1) : YumojiTheme.surfaceSecondary.opacity(0.85)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

/// Compact floating Fit-All + zoom badge + add menu shown when no sticker is selected.
@MainActor
struct BoardUnselectedControls: View {
    let zoom: CGFloat
    let cameraAvailable: Bool
    let onFitAll: () -> Void
    let onResetZoom: () -> Void
    let onOpenCamera: () -> Void
    let onOpenPhotosPicker: () -> Void

    @Environment(LanguageManager.self) private var lang

    var body: some View {
        HStack {
            HStack(spacing: 0) {
                Button(action: onFitAll) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(YumojiTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .accessibilityLabel(lang.t("board.action.fit_all"))

                Rectangle()
                    .fill(YumojiTheme.ink.opacity(0.12))
                    .frame(width: 1, height: 18)

                Button(action: onResetZoom) {
                    Text("\(Int(round(zoom * 100)))%")
                        .font(YumojiTheme.rounded(13, weight: .semibold))
                        .foregroundStyle(YumojiTheme.inkSoft)
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .accessibilityLabel(lang.t("board.action.reset_zoom"))
            }
            .background(YumojiTheme.card.opacity(0.95), in: Capsule())
            .overlay(
                Capsule().strokeBorder(YumojiTheme.ink.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: YumojiTheme.shadow.opacity(0.6), radius: 10, y: 4)

            Spacer()

            Menu {
                if cameraAvailable {
                    Button(action: onOpenCamera) {
                        Label(lang.t("home.take_photo"), systemImage: "camera.fill")
                    }
                }
                Button(action: onOpenPhotosPicker) {
                    Label(lang.t("home.pick_from_library"), systemImage: "photo.on.rectangle")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(YumojiTheme.accent, in: Circle())
                    .shadow(color: YumojiTheme.shadow.opacity(0.75), radius: 10, y: 4)
            }
            .accessibilityLabel(lang.t("board.action.add"))
        }
    }
}

/// Infinite bullet-journal dot grid rendered in screen space so panning and zooming
/// never clip or hit artificial walls.
struct InfiniteDotGridCanvas: View {
    let viewport: BoardViewport
    let viewportSize: CGSize
    var baseSpacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(YumojiTheme.cream))
            let spacing = max(14, baseSpacing * viewport.zoom)
            let dotSize = min(3.4, max(1.4, 2.2 * viewport.zoom))
            let dotColor = YumojiTheme.inkSoft.opacity(0.22)

            let originX = (size.width / 2 + viewport.offset.width)
                .truncatingRemainder(dividingBy: spacing)
            let originY = (size.height / 2 + viewport.offset.height)
                .truncatingRemainder(dividingBy: spacing)

            let startX = originX >= 0 ? originX : originX + spacing
            let startY = originY >= 0 ? originY : originY + spacing

            var y = startY
            while y < size.height {
                var x = startX
                while x < size.width {
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
