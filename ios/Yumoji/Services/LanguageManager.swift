import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans = "zh-Hans"
    case english = "en"

    var id: String { rawValue }
}

enum ResolvedLanguage: String, Equatable, Sendable {
    case zhHans = "zh-Hans"
    case english = "en"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func resolve(
        preference: AppLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> ResolvedLanguage {
        switch preference {
        case .zhHans:
            return .zhHans
        case .english:
            return .english
        case .system:
            guard let primary = preferredLanguages.first?.lowercased() else {
                return .english
            }
            if primary == "zh" || primary.hasPrefix("zh-") || primary.hasPrefix("zh_") {
                return .zhHans
            }
            return .english
        }
    }

    static func current(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> ResolvedLanguage {
        let raw = defaults.string(forKey: LanguageManager.storageKey)
        let preference = raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
        return resolve(preference: preference, preferredLanguages: preferredLanguages)
    }
}

enum L10n {
    static func bundle(for language: ResolvedLanguage, in baseBundle: Bundle = .main) -> Bundle {
        if let path = baseBundle.path(forResource: language.rawValue, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            return localizedBundle
        }
        return baseBundle
    }

    static func string(
        _ key: String,
        language: ResolvedLanguage,
        in baseBundle: Bundle = .main
    ) -> String {
        bundle(for: language, in: baseBundle)
            .localizedString(forKey: key, value: key, table: nil)
    }

    static func format(
        _ key: String,
        language: ResolvedLanguage,
        in baseBundle: Bundle = .main,
        _ args: CVarArg...
    ) -> String {
        format(key, language: language, in: baseBundle, arguments: args)
    }

    static func format(
        _ key: String,
        language: ResolvedLanguage,
        in baseBundle: Bundle = .main,
        arguments: [CVarArg]
    ) -> String {
        let template = string(key, language: language, in: baseBundle)
        return String(format: template, locale: language.locale, arguments: arguments)
    }
}

@Observable
@MainActor
final class LanguageManager {
    static let storageKey = "yumoji.appLanguage"

    var selection: AppLanguage {
        didSet {
            defaults.set(selection.rawValue, forKey: Self.storageKey)
        }
    }

    private(set) var systemPreferredLanguages: [String]
    private let defaults: UserDefaults
    private let baseBundle: Bundle

    init(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages,
        baseBundle: Bundle = .main
    ) {
        self.defaults = defaults
        self.baseBundle = baseBundle
        self.systemPreferredLanguages = preferredLanguages
        let saved = defaults.string(forKey: Self.storageKey).flatMap(AppLanguage.init(rawValue:))
        self.selection = saved ?? .system
    }

    var resolved: ResolvedLanguage {
        ResolvedLanguage.resolve(
            preference: selection,
            preferredLanguages: systemPreferredLanguages
        )
    }

    var locale: Locale {
        resolved.locale
    }

    func refreshSystemLanguages(_ preferredLanguages: [String] = Locale.preferredLanguages) {
        if systemPreferredLanguages != preferredLanguages {
            systemPreferredLanguages = preferredLanguages
        }
    }

    func t(_ key: String) -> String {
        L10n.string(key, language: resolved, in: baseBundle)
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        L10n.format(key, language: resolved, in: baseBundle, arguments: args)
    }
}
