import Foundation

/// Result of analysing one meal photo. Mirrors the JSON in `docs/api.md`.
struct FoodAnalysis: Codable, Equatable, Sendable {
    /// Upper bound for `intro`, in characters.
    static let introLimit = 40

    let name: String
    /// Rough estimate for the whole serving; nil when unknown or not food.
    let kcal: Int?
    let intro: String
    let isFood: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case kcal
        case intro
        case isFood = "is_food"
    }

    /// `约 520 千卡`, or nil when there is no estimate to show.
    var kcalText: String? {
        kcalText(language: .zhHans)
    }

    func kcalText(language: ResolvedLanguage) -> String? {
        guard isFood, let kcal else { return nil }
        return FoodAnalysis.formatKcal(kcal, language: language)
    }

    /// The intro, cut to the contract length in case the service overshoots.
    var displayIntro: String {
        String(intro.prefix(FoodAnalysis.introLimit))
    }

    static func formatKcal(_ kcal: Int, language: ResolvedLanguage = .zhHans) -> String {
        let clamped = max(0, kcal)
        switch language {
        case .zhHans:
            return "约 \(clamped) 千卡"
        case .english:
            return "~\(clamped) kcal"
        case .japanese:
            return "約 \(clamped) kcal"
        }
    }
}
