import SwiftData
import SwiftUI
import UIKit

private enum AppRoute: Hashable {
    case board(focusStickerID: UUID?)
    case result
}

private enum CaptureOrigin {
    case grid
    case board
}

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var lang

    @Query(sort: \StickerRecord.createdAt, order: .reverse) private var stickers: [StickerRecord]
    @Query private var placements: [BoardItemPlacement]

    @State private var session = StickerSession()
    @State private var navPath: [AppRoute] = []
    @State private var captureOrigin: CaptureOrigin = .grid
    @State private var boardCenterAnchor: CGPoint = .zero
    @State private var selectedBoardStickerID: UUID?
    @State private var inspectedSticker: StickerRecord?
    @State private var pendingExportFromDetail: UIImage?
    @State private var showCamera = false
    @State private var showSettings = false
    @State private var exportPayload: ExportPayload?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ZStack {
            YumojiTheme.cream.ignoresSafeArea()

            NavigationStack(path: $navPath) {
                HomeView(
                    appVersion: AppUpdate.marketingVersion(),
                    stickers: stickers,
                    onOpenCamera: {
                        captureOrigin = .grid
                        showCamera = true
                    },
                    onPhoto: { input in
                        startCapture(input, origin: .grid)
                    },
                    onOpenSettings: {
                        showSettings = true
                    },
                    onSelectSticker: { record in
                        inspectedSticker = record
                    }
                )
                .navigationTitle(stickers.isEmpty ? "" : lang.t("grid.title"))
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

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                openBoard(focusStickerID: nil)
                            } label: {
                                Image(systemName: "rectangle.on.rectangle")
                            }
                            .accessibilityLabel(lang.t("grid.open_board"))
                            .foregroundStyle(YumojiTheme.ink)
                        }
                    }
                    settingsButton
                }
                .yumojiNavigationBar()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .board(let focusStickerID):
                        StickerBoardView(
                            stickers: stickers,
                            placements: placements.filter { $0.boardID == StickerRecord.defaultBoardID },
                            initialFocusStickerID: focusStickerID,
                            selectedStickerID: $selectedBoardStickerID,
                            cameraAvailable: cameraAvailable,
                            onOpenCamera: {
                                captureOrigin = .board
                                showCamera = true
                            },
                            onPhoto: { input in
                                startCapture(input, origin: .board)
                            },
                            onExportSticker: { image in
                                exportPayload = ExportPayload(image: image)
                            },
                            onViewportCenterChanged: { center in
                                boardCenterAnchor = center
                            }
                        )
                        .navigationTitle(lang.t("board.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { settingsButton }
                        .yumojiNavigationBar()

                    case .result:
                        ResultView(
                            session: session,
                            saveLabelKey: captureOrigin == .board ? "result.save_to_board" : "result.save_sticker",
                            onSaveToBoard: { sticker, capturedAt in
                                saveSticker(sticker, capturedAt: capturedAt)
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
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onImage: { image in
                    showCamera = false
                    startCapture(.camera(image), origin: captureOrigin)
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
                    selectedBoardStickerID = nil
                    inspectedSticker = nil
                    navPath.removeAll()
                }
            )
            .environment(\.locale, lang.locale)
            .preferredColorScheme(themeManager.selection.resolved(against: colorScheme))
        }
        .sheet(item: $inspectedSticker, onDismiss: {
            if let pending = pendingExportFromDetail {
                pendingExportFromDetail = nil
                exportPayload = ExportPayload(image: pending)
            }
        }) { record in
            StickerDetailSheet(
                record: record,
                onViewOnBoard: { stickerID in
                    openBoard(focusStickerID: stickerID)
                },
                onExport: { image in
                    pendingExportFromDetail = image
                },
                onDelete: { target in
                    deleteSticker(target)
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
            syncBoardPlacements()
        }
        .onChange(of: stickers.count) { _, _ in
            syncBoardPlacements()
        }
        .onChange(of: session.isActive) { _, isActive in
            if !isActive, navPath.last == .result {
                navPath.removeLast()
            }
        }
        .onChange(of: navPath) { _, newPath in
            if !newPath.contains(.result), session.isActive {
                session.reset()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                lang.refreshSystemLanguages()
            }
        }
    }

    private func startCapture(_ input: PhotoInput, origin: CaptureOrigin) {
        captureOrigin = origin
        session.start(input)
        if navPath.last != .result {
            navPath.append(.result)
        }
    }

    private func openBoard(focusStickerID: UUID?) {
        syncBoardPlacements()
        selectedBoardStickerID = focusStickerID
        navPath.append(.board(focusStickerID: focusStickerID))
    }

    private func saveSticker(_ sticker: UIImage, capturedAt: Date?) {
        guard let cgImage = sticker.cgImage else { return }
        let anchor: CGPoint? = (captureOrigin == .board) ? boardCenterAnchor : nil
        if let saved = try? StickerStorage.saveSticker(
            cgImage,
            capturedAt: capturedAt,
            preferredAnchor: anchor,
            in: modelContext
        ) {
            if captureOrigin == .board {
                selectedBoardStickerID = saved.id
            }
            session.reset()
        }
    }

    private func deleteSticker(_ record: StickerRecord) {
        if selectedBoardStickerID == record.id {
            selectedBoardStickerID = nil
        }
        if inspectedSticker?.id == record.id {
            inspectedSticker = nil
        }
        try? StickerStorage.delete(record, in: modelContext)
    }

    private func syncBoardPlacements() {
        StickerStorage.ensureBoardPlacements(for: stickers, in: modelContext)
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
