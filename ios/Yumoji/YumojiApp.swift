import SwiftData
import SwiftUI

@main
struct YumojiApp: App {
    @State private var themeManager = ThemeManager()
    @State private var languageManager = LanguageManager()
    @State private var soundEffects = SoundEffects()
    @State private var exportPalette = ExportPaletteStore()

    private let modelContainer: ModelContainer

    init() {
        if let container = try? StickerStorage.makeContainer() {
            self.modelContainer = container
        } else {
            self.modelContainer = try! StickerStorage.makeContainer(inMemory: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .environment(languageManager)
                .environment(soundEffects)
                .environment(exportPalette)
                .environment(\.locale, languageManager.locale)
                .preferredColorScheme(themeManager.selection.preferredColorScheme)
                .tint(YumojiTheme.accent)
        }
        .modelContainer(modelContainer)
    }
}
