import CoreGraphics
import SwiftUI
import UIKit

/// sRGB color value persisted for export backgrounds and custom swatches.
struct RGBAColor: Codable, Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }

    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    init(uiColor: UIColor) {
        var r: CGFloat = 1
        var g: CGFloat = 1
        var b: CGFloat = 1
        var a: CGFloat = 1
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.init(red: Double(r), green: Double(g), blue: Double(b))
        } else if let srgb = CGColorSpace(name: CGColorSpace.sRGB),
                  let converted = uiColor.cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
                  let comps = converted.components,
                  comps.count >= 3 {
            self.init(red: Double(comps[0]), green: Double(comps[1]), blue: Double(comps[2]))
        } else {
            self.init(hex: 0xFFFFFF)
        }
    }

    init(color: Color) {
        self.init(uiColor: UIColor(color))
    }

    /// Canonical uppercase hex string (`#RRGGBB`) used for deduplication.
    var hexString: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    var cgColor: CGColor {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CGColor(colorSpace: space, components: [red, green, blue, 1]) ?? UIColor.white.cgColor
    }
}

enum ExportBackgroundOption: Codable, Equatable, Hashable, Sendable {
    case transparent
    case solid(RGBAColor)

    var isTransparent: Bool {
        if case .transparent = self { return true }
        return false
    }

    var solidColor: RGBAColor? {
        if case .solid(let color) = self { return color }
        return nil
    }
}

/// Curated warm & cool background presets for sticker export.
enum ExportBackgroundPresets {
    static let warm: [RGBAColor] = [
        RGBAColor(hex: 0xFDEBD2), // Cream Apricot
        RGBAColor(hex: 0xF9C6AD), // Peach Coral
    ]

    static let cool: [RGBAColor] = [
        RGBAColor(hex: 0xD8ECFA), // Sky Mist
        RGBAColor(hex: 0xD6ECE2), // Sage Mint
    ]

    static let all: [RGBAColor] = warm + cool

    static func contains(_ color: RGBAColor) -> Bool {
        all.contains { $0.hexString == color.hexString }
    }
}
