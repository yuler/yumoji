import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var lang

    @State private var session = StickerSession()
    @State private var showCamera = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            YumojiTheme.cream.ignoresSafeArea()

            if session.isActive {
                ResultView(session: session)
            } else {
                HomeView(
                    onOpenCamera: {
                        showCamera = true
                    },
                    onPhoto: { input in
                        session.start(input, language: lang.resolved)
                    },
                    onOpenSettings: {
                        showSettings = true
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onImage: { image in
                    showCamera = false
                    session.start(.camera(image), language: lang.resolved)
                },
                onCancel: {
                    showCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView()
                .environment(\.locale, lang.locale)
                .preferredColorScheme(themeManager.selection.preferredColorScheme)
        }
        .task {
            lang.refreshSystemLanguages()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                lang.refreshSystemLanguages()
            }
        }
    }
}
