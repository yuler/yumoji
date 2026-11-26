import SwiftUI

/// Dish name, rough calories and the one-line intro, or the state it is in.
@MainActor
struct AnalysisCardView: View {
    let state: AnalysisState
    let onRetry: () -> Void

    @Environment(LanguageManager.self) private var lang

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(YumojiTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text(lang.t("analysis.loading"))
                    .font(YumojiTheme.rounded(14))
                    .foregroundStyle(YumojiTheme.inkSoft)
            }
        case .loaded(let analysis):
            details(analysis)
        case .failed:
            HStack {
                Text(lang.t("analysis.failed"))
                    .font(YumojiTheme.rounded(20, weight: .bold))
                    .foregroundStyle(YumojiTheme.inkSoft)
                Spacer()
                Button {
                    onRetry()
                } label: {
                    Label(lang.t("analysis.retry"), systemImage: "arrow.clockwise")
                        .font(YumojiTheme.rounded(15, weight: .semibold))
                }
            }
        }
    }

    private func details(_ analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(analysis.name)
                    .font(YumojiTheme.rounded(24, weight: .bold))
                    .foregroundStyle(YumojiTheme.ink)
                Spacer()
                if let kcalText = analysis.kcalText(language: lang.resolved) {
                    Text(kcalText)
                        .font(YumojiTheme.rounded(15, weight: .medium))
                        .foregroundStyle(YumojiTheme.accent)
                }
            }

            if !analysis.isFood {
                Text(lang.t("analysis.not_food"))
                    .font(YumojiTheme.rounded(13, weight: .medium))
                    .foregroundStyle(YumojiTheme.accent)
            }

            Text(analysis.displayIntro)
                .font(YumojiTheme.rounded(15))
                .foregroundStyle(YumojiTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
