import Foundation

/// Frame-by-frame cut and fall progress from a phase start time.
/// SwiftUI implicit animations do not interpolate `Canvas` or sampled contour points.
enum RevealTiming {
    struct Progress: Equatable {
        var cut: CGFloat
        var fall: CGFloat
    }

    static func linear(elapsed: TimeInterval, duration: TimeInterval) -> CGFloat {
        clampedUnit(elapsed, duration: duration)
    }

    /// Cubic ease-in, matching a slow start that accelerates toward the end.
    static func easeIn(elapsed: TimeInterval, duration: TimeInterval) -> CGFloat {
        let t = clampedUnit(elapsed, duration: duration)
        return t * t * t
    }

    static func progress(
        phase: CutoutRevealPhase,
        startedAt: Date?,
        now: Date,
        cutDuration: TimeInterval,
        fallDuration: TimeInterval
    ) -> Progress {
        let elapsed = now.timeIntervalSince(startedAt ?? now)
        switch phase {
        case .scanning:
            return Progress(cut: 0, fall: 0)
        case .cutting:
            return Progress(cut: linear(elapsed: elapsed, duration: cutDuration), fall: 0)
        case .falling:
            return Progress(cut: 1, fall: easeIn(elapsed: elapsed, duration: fallDuration))
        case .settled:
            return Progress(cut: 1, fall: 1)
        }
    }

    private static func clampedUnit(_ elapsed: TimeInterval, duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 1 }
        return CGFloat(min(max(elapsed / duration, 0), 1))
    }
}
