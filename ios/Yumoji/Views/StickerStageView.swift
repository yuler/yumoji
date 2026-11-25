import SwiftUI
import UIKit

/// The warm stage at the top of the result screen. While the cutout runs it
/// shows the photo with a scan sweep; when the cutout is ready the photo dims
/// away and the sticker lifts off from where the subject sat.
@MainActor
struct StickerStageView: View {
    let session: StickerSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appearedAt = Date()
    @State private var breathing = false
    @State private var photoDimmed = false
    @State private var stickerShown = false
    @State private var popped = false
    @State private var lifted = false
    @State private var hasRevealed = false

    /// The scan sweep always runs at least this long, so a fast cutout still reads as one.
    private let minimumScan: TimeInterval = 0.9
    private let stagePadding: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(YumojiTheme.stage)

            if isProblem {
                problemContent
                    .padding(stagePadding)
                    .transition(.opacity)
            } else {
                GeometryReader { proxy in
                    let available = CGSize(
                        width: max(proxy.size.width - 2 * stagePadding, 0),
                        height: max(proxy.size.height - 2 * stagePadding, 0)
                    )
                    ZStack {
                        photoLayer
                        stickerLayer(available: available)
                    }
                    .frame(width: available.width, height: available.height)
                    .padding(stagePadding)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .animation(.easeOut(duration: 0.25), value: isProblem)
        .task(id: session.cutout) {
            if session.cutout == .ready {
                await reveal()
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
        }
    }

    private var isProblem: Bool {
        switch session.cutout {
        case .noSubject, .failed: true
        case .working, .ready: false
        }
    }

    // MARK: - Layers

    @ViewBuilder
    private var photoLayer: some View {
        if let photo = session.photoImage {
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if !photoDimmed && !reduceMotion {
                        ScanSweep()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .scaleEffect(breathing ? 1.02 : 1)
                .brightness(photoDimmed ? -0.35 : 0)
                .opacity(photoDimmed ? 0 : 1)
        }
    }

    @ViewBuilder
    private func stickerLayer(available: CGSize) -> some View {
        if let sticker = session.sticker {
            let start = startPose(available: available)
            let atRest = popped || reduceMotion
            Image(uiImage: sticker)
                .resizable()
                .scaledToFit()
                .shadow(
                    color: YumojiTheme.shadow.opacity(atRest ? 1 : 0),
                    radius: 10,
                    x: 0,
                    y: 6
                )
                .rotationEffect(.degrees(atRest ? 0 : -3))
                .scaleEffect((atRest ? 1 : start.scale) * (lifted ? 1.08 : 1))
                .offset(atRest ? .zero : start.offset)
                .opacity(stickerShown ? 1 : 0)
        }
    }

    private func startPose(available: CGSize) -> RevealGeometry.Start {
        guard let photo = session.photoImage,
              let crop = session.stickerCrop,
              let start = RevealGeometry.start(
                  photo: CGSize(width: photo.size.width * photo.scale, height: photo.size.height * photo.scale),
                  crop: crop,
                  available: available
              )
        else { return RevealGeometry.Start(scale: 1, offset: .zero) }
        return start
    }

    // MARK: - Reveal

    private func reveal() async {
        guard !hasRevealed else { return }

        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.prepare()

        let remaining = minimumScan - Date().timeIntervalSince(appearedAt)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
        guard !Task.isCancelled else { return }
        hasRevealed = true

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) {
                photoDimmed = true
                stickerShown = true
            }
            haptic.impactOccurred()
            return
        }

        // The sticker appears over the photo, exactly on the subject.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            stickerShown = true
        }
        withAnimation(.easeOut(duration: 0.2)) {
            breathing = false
        }
        withAnimation(.easeOut(duration: 0.35)) {
            photoDimmed = true
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
            popped = true
        }
        withAnimation(.easeOut(duration: 0.18)) {
            lifted = true
        }

        try? await Task.sleep(for: .milliseconds(180))
        haptic.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
            lifted = false
        }
    }

    // MARK: - Problem

    @ViewBuilder
    private var problemContent: some View {
        switch session.cutout {
        case .noSubject:
            problem(
                title: "没找到可以做成贴纸的食物",
                detail: "换个角度，或者让食物在画面里更突出一些。"
            )
        case .failed(let message):
            problem(title: "抠图没有成功", detail: message)
        case .working, .ready:
            EmptyView()
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

/// A soft diagonal highlight that loops across whatever it overlays.
private struct ScanSweep: View {
    private let period: TimeInterval = 0.9

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let progress = (time / period).truncatingRemainder(dividingBy: 1)
            GeometryReader { proxy in
                ZStack {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.45, height: proxy.size.height * 1.8)
                    .rotationEffect(.degrees(20))
                    .offset(x: (progress - 0.5) * proxy.size.width * 1.6)
                    .blendMode(.plusLighter)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}
