import SwiftUI
import UIKit

/// Sticker on top, analysis under it, tuning sliders at the bottom.
@MainActor
struct ResultView: View {
    let session: StickerSession

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 18) {
                    stage

                    if showsAnalysis {
                        AnalysisCardView(
                            state: session.analysis,
                            onRetry: {
                                session.retryAnalysis()
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
                Label("再来一张", systemImage: "chevron.left")
                    .font(YumojiTheme.rounded(16, weight: .semibold))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var stage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(YumojiTheme.stage)
            stageContent
                .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }

    @ViewBuilder
    private var stageContent: some View {
        switch session.cutout {
        case .working:
            VStack(spacing: 12) {
                ProgressView()
                Text("正在抠图…")
                    .font(YumojiTheme.rounded(14))
                    .foregroundStyle(YumojiTheme.inkSoft)
            }
        case .ready:
            if let sticker = session.sticker {
                Image(uiImage: sticker)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: YumojiTheme.shadow, radius: 10, x: 0, y: 6)
            }
        case .noSubject:
            problem(
                title: "没找到可以做成贴纸的食物",
                detail: "换个角度，或者让食物在画面里更突出一些。"
            )
        case .failed(let message):
            problem(title: "抠图没有成功", detail: message)
        }
    }

    private func problem(title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Text("🥲")
                .font(.system(size: 44))
            Text(title)
                .font(YumojiTheme.rounded(17, weight: .semibold))
                .foregroundStyle(YumojiTheme.ink)
            Text(detail)
                .font(YumojiTheme.rounded(13))
                .foregroundStyle(YumojiTheme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                session.reset()
            } label: {
                Text("换一张照片")
                    .font(YumojiTheme.rounded(15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(YumojiTheme.accent, in: Capsule())
            }
            .padding(.top, 6)
        }
    }
}
