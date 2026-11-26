import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager

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
                        session.start(input)
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
                    session.start(.camera(image))
                },
                onCancel: {
                    showCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView()
                .preferredColorScheme(themeManager.selection.preferredColorScheme)
        }
    }
}
