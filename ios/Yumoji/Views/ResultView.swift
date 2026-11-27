import SwiftUI
import UIKit

/// Sticker preview on top, save-to-board & export actions under it, border tuning at the bottom.
@MainActor
struct ResultView: View {
    let session: StickerSession
    let onSaveToBoard: (UIImage, Date?) -> Void
    let onOpenExport: (UIImage) -> Void

    @Environment(LanguageManager.self) private var lang
    @State private var isSavingToBoard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                StickerStageView(session: session)

                if session.cutout == .ready, let sticker = session.sticker {
                    actionBar(for: sticker)
                    StickerTuningView(session: session)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YumojiTheme.cream.ignoresSafeArea())
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
                    Text(isSavingToBoard ? lang.t("result.saving") : lang.t("result.save_to_board"))
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
