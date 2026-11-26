import Foundation
import Observation
import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    /// Scheme to apply on a sheet. `nil` means "no preference", and a sheet that
    /// already has one does not clear it, so system has to be a real scheme.
    func resolved(against system: ColorScheme) -> ColorScheme {
        switch self {
        case .system:
            return system
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@Observable
@MainActor
final class ThemeManager {
    static let storageKey = "yumoji.themeMode"

    var selection: ThemeMode {
        didSet {
            defaults.set(selection.rawValue, forKey: Self.storageKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.storageKey).flatMap(ThemeMode.init(rawValue:))
        self.selection = saved ?? .system
    }
}
