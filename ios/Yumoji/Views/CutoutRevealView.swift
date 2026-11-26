import SwiftUI

enum CutoutRevealPhase: Equatable {
    case scanning
    case cutting
    case falling
    case settled
}

/// Photo, scissor pass, and the paper fall. The stage owns the timing.
struct CutoutRevealView: View {
    let photo: UIImage
    let sticker: UIImage?
    let contour: [CGPoint]
    let outsideMask: UIImage?
    let start: RevealGeometry.Start
    var phase: CutoutRevealPhase
    var phaseStartedAt: Date?
    var cutDuration: TimeInterval
    var fallDuration: TimeInterval
    var breathing: Bool
    var sweeps: Bool

    private let corner: CGFloat = 14

    var body: some View {
        TimelineView(.animation(paused: phase != .cutting && phase != .falling)) { context in
            let timing = RevealTiming.progress(
                phase: phase,
                startedAt: phaseStartedAt,
                now: context.date,
                cutDuration: cutDuration,
                fallDuration: fallDuration
            )
            GeometryReader { proxy in
                let frame = proxy.size
                let pixels = CGSize(
                    width: photo.size.width * photo.scale,
                    height: photo.size.height * photo.scale
                )
                let fitted = StageLayout.fittedRect(image: pixels, frame: frame)
                ZStack {
                    if phase == .scanning || phase == .cutting {
                        photoImage(fitted: fitted, showsSweep: sweeps && phase == .scanning)
                            .scaleEffect(phase == .scanning && breathing ? 1.02 : 1)
                            .position(x: fitted.midX, y: fitted.midY)
                        if phase == .cutting {
                            cutOverlay(pixels: pixels, fitted: fitted, frame: frame, cutProgress: timing.cut)
                        }
                    }
                    if phase == .falling {
                        fallingScrap(fitted: fitted, fallProgress: timing.fall)
                        stickerCard(progress: timing.fall)
                    }
                    if phase == .settled {
                        stickerCard(progress: 1)
                    }
                }
                .frame(width: frame.width, height: frame.height)
            }
        }
    }

    private func photoImage(fitted: CGRect, showsSweep: Bool) -> some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFit()
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
                .scaledToFit()
                .frame(width: fitted.width, height: fitted.height)
        } else {
            Color.white.frame(width: fitted.width, height: fitted.height)
        }
    }

    private func stickerCard(progress: CGFloat) -> some View {
        let settled = min(max(progress, 0), 1)
        let scale = start.scale + (1 - start.scale) * settled
        let offset = CGSize(
            width: start.offset.width * (1 - settled),
            height: (start.offset.height - 16) * (1 - settled)
        )
        return Image(uiImage: sticker ?? UIImage())
            .resizable()
            .scaledToFit()
            .opacity(sticker == nil ? 0 : 1)
            .shadow(color: YumojiTheme.shadow.opacity(sticker == nil ? 0 : Double(settled)), radius: 10, x: 0, y: 6)
            .rotation3DEffect(
                .degrees(Double(-52 * (1 - settled))),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.65
            )
            .scaleEffect(scale)
            .offset(offset)
    }

    private func cutOverlay(pixels: CGSize, fitted: CGRect, frame: CGSize, cutProgress: CGFloat) -> some View {
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
            .frame(width: frame.width, height: frame.height)
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
