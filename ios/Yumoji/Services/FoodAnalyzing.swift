import CoreGraphics
import Foundation

enum FoodAnalysisError: Error {
    case unavailable
}

/// Names the dish in a photo and gives a rough calorie figure and a one-line intro.
/// The real implementation will call the backend described in `docs/api.md`,
/// uploading `UploadImage.jpegData(from:)`.
protocol FoodAnalyzing: Sendable {
    /// - Parameter photo: The original photo, upright (not the sticker).
    func analyze(_ photo: CGImage) async throws -> FoodAnalysis
}

/// Stand-in until the backend exists: waits a moment, then returns canned data.
struct MockFoodAnalyzer: FoodAnalyzing {
    static let samples: [FoodAnalysis] = [
        FoodAnalysis(
            name: "番茄炒蛋",
            kcal: 320,
            intro: "酸甜开胃的国民家常菜，鸡蛋嫩滑，番茄多汁。",
            isFood: true
        ),
        FoodAnalysis(
            name: "红烧牛肉面",
            kcal: 650,
            intro: "浓郁的红烧汤头配上劲道面条，大块牛肉炖得软烂入味，吃完整个人都暖了。",
            isFood: true
        ),
        FoodAnalysis(
            name: "抹茶拿铁",
            kcal: nil,
            intro: "微苦的抹茶遇上绵密奶泡，清爽不腻。",
            isFood: true
        ),
    ]

    var delay: Duration = .milliseconds(1500)

    func analyze(_ photo: CGImage) async throws -> FoodAnalysis {
        try await Task.sleep(for: delay)
        return MockFoodAnalyzer.samples.randomElement() ?? MockFoodAnalyzer.samples[0]
    }
}
