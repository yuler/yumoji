import SwiftUI
import UIKit

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

enum YumojiTheme {
    private static func dynamic(
        light: UInt,
        lightAlpha: CGFloat = 1.0,
        dark: UInt,
        darkAlpha: CGFloat = 1.0
    ) -> Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: dark, alpha: darkAlpha)
            }
            return UIColor(hex: light, alpha: lightAlpha)
        })
    }

    static let cream = dynamic(light: 0xFFF6E9, dark: 0x1B1613)
    static let card = dynamic(light: 0xFFFDF8, dark: 0x27201C)
    static let surfaceSecondary = dynamic(light: 0xF3E6D3, dark: 0x322923)
    /// Background behind the sticker; dark enough for the white border to read.
    static let stage = dynamic(light: 0xFFDDB0, dark: 0x3A2E25)
    static let ink = dynamic(light: 0x4A3626, dark: 0xF6EDE4)
    static let inkSoft = dynamic(light: 0x9B8573, dark: 0xB2A192)
    static let accent = dynamic(light: 0xF07447, dark: 0xF28157)
    static let shadow = dynamic(light: 0x7A4A1E, lightAlpha: 0.22, dark: 0x000000, darkAlpha: 0.45)

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
