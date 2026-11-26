import SwiftUI
import UIKit

/// Debug-only sliders for `StickerStyle`. The sticker re-renders live from the
/// mask already computed, and the numbers shown are the ones to report back.
@MainActor
struct StickerTuningView: View {
    @Bindable var session: StickerSession
    @Environment(LanguageManager.self) private var lang
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                slider(lang.t("tuning.border_ratio"), value: $session.style.borderRatio, range: StickerStyle.borderRange)
                slider(lang.t("tuning.edge_smoothing"), value: $session.style.edgeSmoothing, range: StickerStyle.smoothingRange)
                slider(lang.t("tuning.margin_ratio"), value: $session.style.marginRatio, range: StickerStyle.marginRange)

                Text(summary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(YumojiTheme.inkSoft)
                    .textSelection(.enabled)

                Toggle(lang.t("tuning.simulate_failure"), isOn: $session.simulateAnalysisFailure)
                    .font(YumojiTheme.rounded(13))
                    .foregroundStyle(YumojiTheme.ink)

                HStack {
                    Button(lang.t("tuning.reset_defaults")) {
                        session.style = StickerStyle()
                    }
                    Spacer()
                    Button(lang.t("tuning.reanalyze")) {
                        session.retryAnalysis(language: lang.resolved)
                    }
                }
                .font(YumojiTheme.rounded(13, weight: .semibold))
            }
            .padding(.top, 12)
        } label: {
            Text(lang.t("tuning.title"))
                .font(YumojiTheme.rounded(14, weight: .semibold))
                .foregroundStyle(YumojiTheme.inkSoft)
        }
        .padding(16)
        .background(YumojiTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onChange(of: session.style) { _, _ in
            session.styleDidChange()
        }
    }

    private var summary: String {
        let style = session.style
        let border = Double(style.borderWidth(subjectLongSide: session.subjectLongSide))
        var lines: [String] = [
            String(format: "border=%.3f smooth=%.2f margin=%.3f", style.borderRatio, style.edgeSmoothing, style.marginRatio),
            lang.t("tuning.summary.subject", session.subjectLongSide, border),
        ]
        if let sticker = session.sticker {
            lines.append(lang.t("tuning.summary.sticker", Int(sticker.size.width), Int(sticker.size.height)))
        }
        return lines.joined(separator: "\n")
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(YumojiTheme.rounded(13))
                    .foregroundStyle(YumojiTheme.ink)
                Spacer()
                Text(String(format: "%.3f", value.wrappedValue))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(YumojiTheme.ink)
            }
            Slider(value: value, in: range)
        }
    }
}
