import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var lang

    @State private var session = StickerSession()
    @State private var showCamera = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            YumojiTheme.cream.ignoresSafeArea()

            NavigationStack {
                HomeView(
                    appVersion: AppUpdate.marketingVersion(),
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
                .toolbar { settingsButton }
                .yumojiNavigationBar()
                .navigationDestination(isPresented: resultPresented) {
                    ResultView(session: session)
                        .navigationTitle(resultTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { settingsButton }
                        .yumojiNavigationBar()
                }
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
            SettingsSheetView(
                appVersion: AppUpdate.marketingVersion(),
                installChannel: AppUpdate.channel()
            )
            .environment(\.locale, lang.locale)
            .preferredColorScheme(themeManager.selection.resolved(against: colorScheme))
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

    private var resultPresented: Binding<Bool> {
        Binding(
            get: { session.isActive },
            set: { presented in
                if !presented {
                    session.reset()
                }
            }
        )
    }

    private var resultTitle: String {
        if case .loaded(let analysis) = session.analysis, !analysis.name.isEmpty {
            return analysis.name
        }
        return lang.t("result.title")
    }

    @ToolbarContentBuilder
    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(lang.t("home.settings"))
            .foregroundStyle(YumojiTheme.ink)
        }
    }
}

private extension View {
    func yumojiNavigationBar() -> some View {
        toolbarBackground(YumojiTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
