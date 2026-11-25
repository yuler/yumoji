import SwiftUI
import UIKit

/// Debug-only sliders for `StickerStyle`. The sticker re-renders live from the
/// mask already computed, and the numbers shown are the ones to report back.
@MainActor
struct StickerTuningView: View {
    @Bindable var session: StickerSession
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                slider("白边宽度 borderRatio", value: $session.style.borderRatio, range: StickerStyle.borderRange)
                slider("白边平滑 edgeSmoothing", value: $session.style.edgeSmoothing, range: StickerStyle.smoothingRange)
                slider("透明留白 marginRatio", value: $session.style.marginRatio, range: StickerStyle.marginRange)

                Text(summary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(YumojiTheme.inkSoft)
                    .textSelection(.enabled)

                Toggle("下次识别模拟失败", isOn: $session.simulateAnalysisFailure)
                    .font(YumojiTheme.rounded(13))
                    .foregroundStyle(YumojiTheme.ink)

                HStack {
                    Button("恢复默认参数") {
                        session.style = StickerStyle()
                    }
                    Spacer()
                    Button("重新识别") {
                        session.retryAnalysis()
                    }
                }
                .font(YumojiTheme.rounded(13, weight: .semibold))
            }
            .padding(.top, 12)
        } label: {
            Text("调试 · 贴纸参数")
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
        let border = style.borderWidth(subjectLongSide: session.subjectLongSide)
        var lines: [String] = [
            String(format: "border=%.3f smooth=%.2f margin=%.3f", style.borderRatio, style.edgeSmoothing, style.marginRatio),
            "主体长边 \(session.subjectLongSide) px · 白边 " + String(format: "%.1f", border) + " px",
        ]
        if let sticker = session.sticker {
            lines.append("贴纸 \(Int(sticker.size.width)) × \(Int(sticker.size.height)) px")
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
