import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @State private var session = StickerSession()
    @State private var showCamera = false

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
    }
}
