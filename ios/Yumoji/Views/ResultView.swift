import SwiftUI
import UIKit

/// Sticker on top, analysis under it, tuning sliders at the bottom.
@MainActor
struct ResultView: View {
    let session: StickerSession

    @Environment(LanguageManager.self) private var lang

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 18) {
                    StickerStageView(session: session)

                    if session.cutout == .ready, let sticker = session.sticker {
                        StickerExportBar(image: sticker)
                    }

                    if showsAnalysis {
                        AnalysisCardView(
                            state: session.analysis,
                            onRetry: {
                                session.retryAnalysis(language: lang.resolved)
                            }
                        )
                    }

                    if session.cutout == .ready {
                        StickerTuningView(session: session)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YumojiTheme.cream.ignoresSafeArea())
    }

    private var showsAnalysis: Bool {
        session.cutout == .working || session.cutout == .ready
    }

    private var header: some View {
        HStack {
            Button {
                session.reset()
            } label: {
                Label(lang.t("result.another"), systemImage: "chevron.left")
                    .font(YumojiTheme.rounded(16, weight: .semibold))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
