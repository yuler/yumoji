import Foundation
import Observation

/// Persists the last selected export background and user-picked custom swatches.
@Observable
@MainActor
final class ExportPaletteStore {
    static let maxCustomColors = 6

    private static let selectedKey = "yumoji.export.selectedBackground"
    private static let customColorsKey = "yumoji.export.customColors"

    private let defaults: UserDefaults

    private(set) var selected: ExportBackgroundOption
    private(set) var customColors: [RGBAColor]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.selectedKey),
           let decoded = try? JSONDecoder().decode(ExportBackgroundOption.self, from: data) {
            self.selected = decoded
        } else {
            self.selected = .transparent
        }

        if let data = defaults.data(forKey: Self.customColorsKey),
           let decoded = try? JSONDecoder().decode([RGBAColor].self, from: data) {
            self.customColors = Array(decoded.prefix(Self.maxCustomColors))
        } else {
            self.customColors = []
        }
    }

    func select(_ option: ExportBackgroundOption) {
        selected = option
        persist()
    }

    /// Saves a color picked from the system ColorPicker and selects it.
    /// Passing `replacing` updates the active draft swatch in-place while dragging.
    @discardableResult
    func applyPickedColor(_ color: RGBAColor, replacing previousDraft: RGBAColor? = nil) -> RGBAColor {
        if ExportBackgroundPresets.contains(color) {
            if let previousDraft {
                customColors.removeAll { $0.hexString == previousDraft.hexString }
            }
            selected = .solid(color)
            persist()
            return color
        }

        if let previousDraft,
           let index = customColors.firstIndex(where: { $0.hexString == previousDraft.hexString }) {
            customColors.remove(at: index)
        }
        customColors.removeAll { $0.hexString == color.hexString }
        customColors.insert(color, at: 0)
        if customColors.count > Self.maxCustomColors {
            customColors = Array(customColors.prefix(Self.maxCustomColors))
        }
        selected = .solid(color)
        persist()
        return color
    }

    func removeCustomColor(_ color: RGBAColor) {
        customColors.removeAll { $0.hexString == color.hexString }
        if case .solid(let current) = selected, current.hexString == color.hexString {
            selected = .transparent
        }
        persist()
    }

    private func persist() {
        if let selectedData = try? JSONEncoder().encode(selected) {
            defaults.set(selectedData, forKey: Self.selectedKey)
        }
        if let customData = try? JSONEncoder().encode(customColors) {
            defaults.set(customData, forKey: Self.customColorsKey)
        }
    }
}
