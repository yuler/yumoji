import CoreGraphics

enum SubjectLiftingError: Error {
    /// The photo has nothing that stands out as a foreground subject.
    case noSubject
}

/// Finds the foreground subject of a photo. Behind a protocol because the real
/// implementation (Vision) does not run in the simulator.
protocol SubjectLifting: Sendable {
    /// - Parameter image: The photo, already upright.
    /// - Returns: One mask with every detected foreground instance merged, the same pixel size as `image`.
    /// - Throws: `SubjectLiftingError.noSubject` when nothing is found.
    func liftSubject(from image: CGImage) async throws -> SubjectMask
}
