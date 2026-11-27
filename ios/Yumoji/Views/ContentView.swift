import SwiftData
import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var lang

    @Query(sort: \StickerRecord.zIndex) private var stickers: [StickerRecord]

    @State private var session = StickerSession()
    @State private var selectedStickerID: UUID?
    @State private var preferredDropY: Double = 240
    @State private var showCamera = false
    @State private var showSettings = false
    @State private var exportPayload: ExportPayload?

    var body: some View {
        ZStack {
            YumojiTheme.cream.ignoresSafeArea()

            NavigationStack {
                HomeView(
                    appVersion: AppUpdate.marketingVersion(),
                    stickers: stickers,
                    selectedStickerID: $selectedStickerID,
                    preferredDropY: $preferredDropY,
                    onOpenCamera: {
                        showCamera = true
                    },
                    onPhoto: { input in
                        session.start(input)
                    },
                    onOpenSettings: {
                        showSettings = true
                    },
                    onExportSticker: { image in
                        exportPayload = ExportPayload(image: image)
                    }
                )
                .navigationTitle(stickers.isEmpty ? "" : lang.t("board.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !stickers.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Text(lang.t("board.count", stickers.count))
                                .font(YumojiTheme.rounded(13, weight: .semibold))
                                .foregroundStyle(YumojiTheme.inkSoft)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(YumojiTheme.card, in: Capsule())
                        }
                    }
                    settingsButton
                }
                .yumojiNavigationBar()
                .navigationDestination(isPresented: resultPresented) {
                    ResultView(
                        session: session,
                        onSaveToBoard: { sticker, capturedAt in
                            saveToBoard(sticker, capturedAt: capturedAt)
                        },
                        onOpenExport: { sticker in
                            exportPayload = ExportPayload(image: sticker)
                        }
                    )
                    .navigationTitle(lang.t("result.title"))
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
                    session.start(.camera(image))
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
                installChannel: AppUpdate.channel(),
                onClearedStickers: {
                    selectedStickerID = nil
                }
            )
            .environment(\.locale, lang.locale)
            .preferredColorScheme(themeManager.selection.resolved(against: colorScheme))
        }
        .sheet(item: $exportPayload) { payload in
            StickerExportSheet(stickerImage: payload.image)
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

    private func saveToBoard(_ sticker: UIImage, capturedAt: Date?) {
        guard let cgImage = sticker.cgImage else { return }
        if let saved = try? StickerStorage.saveSticker(
            cgImage,
            capturedAt: capturedAt,
            preferredY: preferredDropY,
            in: modelContext
        ) {
            selectedStickerID = saved.id
            session.reset()
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

private struct ExportPayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private extension View {
    func yumojiNavigationBar() -> some View {
        toolbarBackground(YumojiTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
