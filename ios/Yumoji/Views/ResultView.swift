import SwiftUI

/// Sticker on top, analysis under it, tuning sliders at the bottom.
@MainActor
struct ResultView: View {
    let session: StickerSession

    @Environment(LanguageManager.self) private var lang

    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YumojiTheme.cream.ignoresSafeArea())
    }

    private var showsAnalysis: Bool {
        session.cutout == .working || session.cutout == .ready
    }
}
