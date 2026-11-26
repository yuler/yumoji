import SwiftUI

enum CutoutRevealPhase: Equatable {
    case scanning
    case cutting
    case falling
    case settled
}

/// Photo, scissor pass, and the paper fall. The stage owns the timing.
/// The photo is drawn in `canvas`; the cut starts from the crop's place on that photo.
struct CutoutRevealView: View {
    let photo: UIImage
    let sticker: UIImage?
    let contour: [CGPoint]
    let outsideMask: UIImage?
    let crop: PixelRect?
    let canvas: CGSize
    var phase: CutoutRevealPhase
    var phaseStartedAt: Date?
    var cutDuration: TimeInterval
    var fallDuration: TimeInterval
    var breathing: Bool
    var sweeps: Bool

    private let corner: CGFloat = 14

    var body: some View {
        let pixels = CGSize(
            width: photo.size.width * photo.scale,
            height: photo.size.height * photo.scale
        )
        let fitted = StageLayout.fittedRect(image: pixels, frame: canvas)
        TimelineView(.animation(paused: phase != .cutting && phase != .falling)) { context in
            let timing = RevealTiming.progress(
                phase: phase,
                startedAt: phaseStartedAt,
                now: context.date,
                cutDuration: cutDuration,
                fallDuration: fallDuration
            )
            ZStack {
                if phase == .scanning || phase == .cutting {
                    photoImage(fitted: fitted, showsSweep: sweeps && phase == .scanning)
                        .scaleEffect(phase == .scanning && breathing ? 1.02 : 1)
                        .position(x: fitted.midX, y: fitted.midY)
                    if phase == .cutting {
                        cutOverlay(pixels: pixels, fitted: fitted, cutProgress: timing.cut)
                    }
                }
                if phase == .falling {
                    fallingScrap(fitted: fitted, fallProgress: timing.fall)
                    stickerCard(pixels: pixels, fitted: fitted, progress: timing.fall)
                }
                if phase == .settled {
                    stickerCard(pixels: pixels, fitted: fitted, progress: 1)
                }
            }
            .frame(width: canvas.width, height: canvas.height)
        }
        .frame(width: canvas.width, height: canvas.height)
    }

    private func photoImage(fitted: CGRect, showsSweep: Bool) -> some View {
        Image(uiImage: photo)
            .resizable()
            .frame(width: fitted.width, height: fitted.height)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay {
                if showsSweep {
                    ScanSweep()
                        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                }
            }
    }

    private func fallingScrap(fitted: CGRect, fallProgress: CGFloat) -> some View {
        let travel = fallProgress * fitted.height * 0.85
        return photoImage(fitted: fitted, showsSweep: false)
            .mask { scrapMask(fitted: fitted) }
            .rotation3DEffect(
                .degrees(Double(fallProgress) * 58),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.45
            )
            .opacity(Double(1 - fallProgress))
            .position(x: fitted.midX, y: fitted.midY + travel)
    }

    @ViewBuilder
    private func scrapMask(fitted: CGRect) -> some View {
        if let outsideMask {
            Image(uiImage: outsideMask)
                .resizable()
                .frame(width: fitted.width, height: fitted.height)
        } else {
            Color.white.frame(width: fitted.width, height: fitted.height)
        }
    }

    @ViewBuilder
    private func stickerCard(pixels: CGSize, fitted: CGRect, progress: CGFloat) -> some View {
        if let sticker, let crop {
            let settled = min(max(progress, 0), 1)
            let stickerPixels = CGSize(
                width: sticker.size.width * sticker.scale,
                height: sticker.size.height * sticker.scale
            )
            let rest = StageLayout.fittedRect(image: stickerPixels, frame: canvas)
            let start = StageLayout.cropRect(crop, image: pixels, fitted: fitted)
            let frame = interpolated(from: start, to: rest, progress: settled)
            Image(uiImage: sticker)
                .resizable()
                .frame(width: frame.width, height: frame.height)
                .shadow(color: YumojiTheme.shadow.opacity(Double(settled)), radius: 10, x: 0, y: 6)
                .rotation3DEffect(
                    .degrees(Double(-52 * (1 - settled))),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.65
                )
                .position(x: frame.midX, y: frame.midY)
        }
    }

    /// Moves the sticker from where the subject sits on the photo to its resting frame.
    /// The extra 16pt is the little lift at the start of the fall.
    private func interpolated(from start: CGRect, to rest: CGRect, progress: CGFloat) -> CGRect {
        let lift = 16 * (1 - progress)
        return CGRect(
            x: start.minX + (rest.minX - start.minX) * progress,
            y: start.minY + (rest.minY - start.minY) * progress - lift,
            width: start.width + (rest.width - start.width) * progress,
            height: start.height + (rest.height - start.height) * progress
        )
    }

    private func cutOverlay(pixels: CGSize, fitted: CGRect, cutProgress: CGFloat) -> some View {
        let points = contour.map { StageLayout.map($0, image: pixels, fitted: fitted) }
        return ZStack {
            Canvas { context, _ in
                var path = Path()
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                path.closeSubpath()
                context.stroke(
                    path.trimmedPath(from: 0, to: cutProgress),
                    with: .color(YumojiTheme.accent),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(width: canvas.width, height: canvas.height)
            if let sample = ContourPath.sample(points: points, progress: cutProgress) {
                Image(systemName: "scissors")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(YumojiTheme.accent)
                    .rotationEffect(.radians(sample.angle))
                    .position(sample.point)
            }
        }
        .allowsHitTesting(false)
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
                LinearGradient(
                    colors: [.clear, .white.opacity(0.55), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.45, height: proxy.size.height * 1.8)
                .rotationEffect(.degrees(20))
                .offset(x: (progress - 0.5) * proxy.size.width * 1.6)
                .blendMode(.plusLighter)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}
