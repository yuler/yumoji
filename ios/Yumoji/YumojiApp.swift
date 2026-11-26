import SwiftUI

@main
struct YumojiApp: App {
    @State private var themeManager = ThemeManager()
    @State private var languageManager = LanguageManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .environment(languageManager)
                .environment(\.locale, languageManager.locale)
                .preferredColorScheme(themeManager.selection.preferredColorScheme)
                .tint(YumojiTheme.accent)
        }
    }
}
