import Foundation
import Observation

/// Whether the cut animation plays its paper-snip and landing sounds.
/// The landing vibration stays on either way.
@Observable
@MainActor
final class SoundEffects {
    static let storageKey = "yumoji.soundEffectsEnabled"

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Self.storageKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.storageKey) == nil {
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: Self.storageKey)
        }
    }
}
