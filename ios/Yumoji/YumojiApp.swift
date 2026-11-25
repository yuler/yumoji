import SwiftUI

@main
struct YumojiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .tint(YumojiTheme.accent)
        }
    }
}
