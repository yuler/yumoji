import SwiftUI
import UIKit

/// The photo at the top of the result screen. While the cutout runs, a scan
/// sweeps the picture. When the subject is ready, scissors trace its outline,
/// the cut piece flips down into the sticker, and the leftover photo falls away.
@MainActor
struct StickerStageView: View {
    let session: StickerSession
    var maxStageHeight: CGFloat = StageLayout.maxHeight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(LanguageManager.self) private var lang
    @Environment(SoundEffects.self) private var sound

    @State private var containerWidth: CGFloat = 320
    @State private var photoPlacedAt: Date?
    @State private var breathing = false
    @State private var phase: CutoutRevealPhase = .scanning
    @State private var phaseStartedAt: Date?
    @State private var hasRevealed = false
    @State private var player = StageSoundPlayer()

    /// The scan always runs at least this long, so a fast cutout still reads as one.
    private let minimumScan: TimeInterval = 0.9
    private let cutDuration: TimeInterval = 0.45
    private let fallDuration: TimeInterval = 0.4

    var body: some View {
        ZStack {
            if isProblem {
                problemContent
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if let photo = session.photoImage {
                let size = StageLayout.frame(
                    image: pixelSize(of: photo),
                    containerWidth: containerWidth,
                    maxHeight: maxStageHeight
                )
                CutoutRevealView(
                    photo: photo,
                    sticker: session.sticker,
                    contour: session.subjectContour,
                    outsideMask: session.outsideMask,
                    crop: session.stickerCrop,
                    canvas: size,
                    phase: phase,
                    phaseStartedAt: phaseStartedAt,
                    cutDuration: cutDuration,
                    fallDuration: fallDuration,
                    breathing: breathing,
                    sweeps: !reduceMotion
                )
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
                .onAppear {
                    if photoPlacedAt == nil {
                        photoPlacedAt = Date()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: StageWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(StageWidthKey.self) { width in
            guard width > 1, abs(width - containerWidth) > 0.5 else { return }
            containerWidth = width
        }
        .animation(.easeOut(duration: 0.25), value: isProblem)
        .task(id: canReveal) {
            guard canReveal else { return }
            await reveal()
        }
        .onChange(of: session.photoImage == nil) { _, isNil in
            if isNil {
                resetRevealState()
            } else if photoPlacedAt == nil {
                photoPlacedAt = Date()
            }
        }
        .onAppear {
            if session.photoImage != nil, photoPlacedAt == nil {
                photoPlacedAt = Date()
            }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
        }
    }

    private var canReveal: Bool {
        session.cutout == .ready && session.photoImage != nil && session.sticker != nil
    }

    private var isProblem: Bool {
        switch session.cutout {
        case .noSubject, .failed: true
        case .working, .ready: false
        }
    }

    private func pixelSize(of photo: UIImage) -> CGSize {
        CGSize(width: photo.size.width * photo.scale, height: photo.size.height * photo.scale)
    }

    private func resetRevealState() {
        hasRevealed = false
        phase = .scanning
        phaseStartedAt = nil
        photoPlacedAt = nil
    }

    private func reveal() async {
        guard !hasRevealed, canReveal else { return }
        if photoPlacedAt == nil {
            photoPlacedAt = Date()
        }
        let remaining = minimumScan - Date().timeIntervalSince(photoPlacedAt ?? Date())
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
        guard !Task.isCancelled, canReveal else { return }
        hasRevealed = true
        if sound.isEnabled {
            player.prepare()
        }

        if reduceMotion {
            phase = .settled
            land()
            return
        }

        let haptic = UIImpactFeedbackGenerator(style: .medium)
        let hasOutline = session.subjectContour.count >= 3
        if hasOutline {
            phaseStartedAt = Date()
            phase = .cutting
            if sound.isEnabled {
                player.playPaperCut()
            }
            try? await Task.sleep(for: .seconds(cutDuration))
            guard !Task.isCancelled else { return }
        }

        phaseStartedAt = Date()
        phase = .falling
        if !hasOutline, sound.isEnabled {
            player.playPaperCut()
        }
        haptic.prepare()
        try? await Task.sleep(for: .seconds(fallDuration))
        guard !Task.isCancelled else { return }
        phase = .settled
        haptic.impactOccurred()
        if sound.isEnabled {
            player.playDong()
        }
    }

    private func land() {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        if sound.isEnabled {
            player.playDong()
        }
    }

    @ViewBuilder
    private var problemContent: some View {
        switch session.cutout {
        case .noSubject:
            problem(
                title: lang.t("stage.no_subject.title"),
                detail: lang.t("stage.no_subject.detail")
            )
        case .failed(let failure):
            problem(
                title: lang.t("stage.failed.title"),
                detail: failureDetail(failure)
            )
        case .working, .ready:
            EmptyView()
        }
    }

    private func failureDetail(_ failure: CutoutFailure) -> String {
        switch failure {
        case .unreadablePhoto:
            return lang.t("stage.failed.unreadable_photo")
        case .composeFailed:
            return lang.t("stage.failed.compose_failed")
        case .message(let text):
            return text
        }
    }

    private func problem(title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Text("🥲")
                .font(.system(size: 44))
            Text(title)
                .font(YumojiTheme.rounded(17, weight: .semibold))
                .foregroundStyle(YumojiTheme.ink)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(YumojiTheme.rounded(13))
                .foregroundStyle(YumojiTheme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                session.reset()
            } label: {
                Text(lang.t("stage.pick_another"))
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

private struct StageWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
