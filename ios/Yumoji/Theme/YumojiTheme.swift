import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum YumojiTheme {
    static let cream = Color(hex: 0xFFF6E9)
    static let card = Color(hex: 0xFFFDF8)
    /// Background behind the sticker; dark enough for the white border to read.
    static let stage = Color(hex: 0xFFDDB0)
    static let ink = Color(hex: 0x4A3626)
    static let inkSoft = Color(hex: 0x9B8573)
    static let accent = Color(hex: 0xF07447)
    static let shadow = Color(hex: 0x7A4A1E, alpha: 0.22)

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
