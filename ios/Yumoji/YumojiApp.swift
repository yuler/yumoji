import SwiftUI

@main
struct YumojiApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .preferredColorScheme(themeManager.selection.preferredColorScheme)
                .tint(YumojiTheme.accent)
        }
    }
}
