import Foundation

/// Tunable sticker look. Lengths are ratios of the subject's long side, so
/// stickers look the same whatever the photo resolution.
struct StickerStyle: Equatable, Sendable {
    /// White border width ÷ subject long side.
    var borderRatio: Double = 0.03
    /// Smoothing of the border's outer edge: blur sigma ÷ border width. 0 turns it off.
    var edgeSmoothing: Double = 0.25
    /// Transparent margin around the bordered subject ÷ subject long side.
    var marginRatio: Double = 0.02

    static let borderRange: ClosedRange<Double> = 0...0.1
    static let smoothingRange: ClosedRange<Double> = 0...1
    static let marginRange: ClosedRange<Double> = 0...0.1

    /// Border width in pixels for a subject of the given size.
    func borderWidth(subjectLongSide: Int) -> Double {
        max(0, borderRatio) * Double(max(0, subjectLongSide))
    }

    /// Transparent margin in pixels for a subject of the given size.
    func marginWidth(subjectLongSide: Int) -> Double {
        max(0, marginRatio) * Double(max(0, subjectLongSide))
    }
}
