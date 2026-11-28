import SwiftUI
import UIKit

/// Sticker preview on top, save-to-board & export actions under it, border tuning at the bottom.
@MainActor
struct ResultView: View {
    let session: StickerSession
    var saveLabelKey: String = "result.save_to_board"
    let onSaveToBoard: (UIImage, Date?) -> Void
    let onOpenExport: (UIImage) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(LanguageManager.self) private var lang
    @State private var isSavingToBoard = false

    var body: some View {
        GeometryReader { proxy in
            let isSideBySide = horizontalSizeClass == .regular && proxy.size.width >= 720

            if isSideBySide {
                sideBySideLayout(in: proxy.size)
            } else {
                stackedLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YumojiTheme.cream.ignoresSafeArea())
    }

    private func sideBySideLayout(in size: CGSize) -> some View {
        let inspectorWidth = min(360, max(300, size.width * 0.34))
        let stageMaxHeight = max(360, size.height - 64)

        return HStack(alignment: .center, spacing: 24) {
            StickerStageView(session: session, maxStageHeight: stageMaxHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if session.cutout == .ready, let sticker = session.sticker {
                ScrollView {
                    VStack(spacing: 18) {
                        actionBar(for: sticker)
                        StickerTuningView(session: session, initiallyExpanded: true)
                    }
                    .padding(.vertical, 4)
                }
                .frame(width: inspectorWidth)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .animation(.easeOut(duration: 0.25), value: session.cutout == .ready)
    }

    private var stackedLayout: some View {
        ScrollView {
            VStack(spacing: 18) {
                StickerStageView(session: session)

                if session.cutout == .ready, let sticker = session.sticker {
                    actionBar(for: sticker)
                    StickerTuningView(session: session)
                }
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private func actionBar(for sticker: UIImage) -> some View {
        VStack(spacing: 10) {
            Button {
                guard !isSavingToBoard else { return }
                isSavingToBoard = true
                onSaveToBoard(sticker, session.capturedAt)
            } label: {
                HStack(spacing: 8) {
                    if isSavingToBoard {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isSavingToBoard ? lang.t("result.saving") : lang.t(saveLabelKey))
                        .lineLimit(1)
                }
                .font(YumojiTheme.rounded(17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(YumojiTheme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(isSavingToBoard)
            .buttonStyle(.plain)

            Button {
                onOpenExport(sticker)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text(lang.t("result.export_share"))
                        .lineLimit(1)
                }
                .font(YumojiTheme.rounded(16, weight: .semibold))
                .foregroundStyle(YumojiTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(YumojiTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
