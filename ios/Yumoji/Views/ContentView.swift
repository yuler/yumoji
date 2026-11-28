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

private enum RegularWorkspace: Hashable {
    case grid
    case board
}

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var lang

    @State private var pager = StickerGridPager()
    @State private var showCardFrame = StickerGridLayout.loadShowCardFrame()
    @State private var session = StickerSession()
    @State private var navPath: [AppRoute] = []
    @State private var regularWorkspace: RegularWorkspace = .grid
    @State private var regularBoardFocusStickerID: UUID?
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

    private var hasStickers: Bool {
        pager.totalCount > 0 || !pager.items.isEmpty
    }

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var showingRegularBoard: Bool {
        isRegularWidth && hasStickers && regularWorkspace == .board
    }

    var body: some View {
        ZStack {
            YumojiTheme.cream.ignoresSafeArea()

            NavigationStack(path: $navPath) {
                Group {
                    if showingRegularBoard {
                        boardView(focusStickerID: regularBoardFocusStickerID)
                    } else {
                        HomeView(
                            appVersion: AppUpdate.marketingVersion(),
                            stickers: pager.items,
                            totalCount: pager.totalCount,
                            hasMore: pager.hasMore,
                            isLoadingMore: pager.isLoading,
                            showCardFrame: showCardFrame,
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
                            },
                            onLoadMore: {
                                pager.loadNextPage(in: modelContext)
                            }
                        )
                    }
                }
                .navigationTitle((hasStickers && !isRegularWidth) ? lang.t("grid.title") : "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if hasStickers && isRegularWidth {
                        ToolbarItem(placement: .principal) {
                            workspaceSwitcher
                        }
                    }

                    if hasStickers && !showingRegularBoard {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCardFrame.toggle()
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: showCardFrame ? "square.inset.filled" : "square.dashed")
                            }
                            .accessibilityLabel(
                                showCardFrame
                                    ? lang.t("grid.frame.hide")
                                    : lang.t("grid.frame.show")
                            )
                            .foregroundStyle(showCardFrame ? YumojiTheme.accent : YumojiTheme.ink)
                        }
                    }

                    if hasStickers && !isRegularWidth {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                openBoard(focusStickerID: nil)
                            } label: {
                                Image(systemName: "square.grid.2x2")
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
                        boardView(focusStickerID: focusStickerID)
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
                    regularBoardFocusStickerID = nil
                    regularWorkspace = .grid
                    navPath.removeAll()
                    pager.reloadPreservingLoadedCount(in: modelContext)
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
            pager.loadInitialIfNeeded(in: modelContext)
        }
        .onChange(of: showCardFrame) { _, newValue in
            StickerGridLayout.saveShowCardFrame(newValue)
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
        .onChange(of: horizontalSizeClass) { _, newClass in
            syncWorkspaceForSizeClass(newClass)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                lang.refreshSystemLanguages()
            }
        }
    }

    private var workspaceSwitcher: some View {
        Picker("", selection: Binding(
            get: { regularWorkspace },
            set: { next in
                if next == .board {
                    StickerStorage.ensureAllBoardPlacements(in: modelContext)
                    regularBoardFocusStickerID = nil
                }
                regularWorkspace = next
            }
        )) {
            Text(lang.t("grid.title")).tag(RegularWorkspace.grid)
            Text(lang.t("board.title")).tag(RegularWorkspace.board)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 220)
    }

    private func boardView(focusStickerID: UUID?) -> some View {
        StickerBoardView(
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
            },
            onStickersMutated: {
                pager.reloadPreservingLoadedCount(in: modelContext)
            }
        )
    }

    private func syncWorkspaceForSizeClass(_ newClass: UserInterfaceSizeClass?) {
        if newClass == .regular {
            if let boardIndex = navPath.firstIndex(where: {
                if case .board = $0 { return true }
                return false
            }) {
                if case .board(let focusID) = navPath[boardIndex] {
                    regularBoardFocusStickerID = focusID
                }
                navPath.remove(at: boardIndex)
                regularWorkspace = .board
            }
        } else if newClass == .compact, regularWorkspace == .board {
            regularWorkspace = .grid
            let alreadyHasBoard = navPath.contains {
                if case .board = $0 { return true }
                return false
            }
            if !alreadyHasBoard {
                navPath.insert(.board(focusStickerID: selectedBoardStickerID), at: 0)
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
        StickerStorage.ensureAllBoardPlacements(in: modelContext)
        selectedBoardStickerID = focusStickerID
        if isRegularWidth {
            regularBoardFocusStickerID = focusStickerID
            regularWorkspace = .board
        } else {
            navPath.append(.board(focusStickerID: focusStickerID))
        }
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
            pager.reloadPreservingLoadedCount(in: modelContext)
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
        pager.reloadPreservingLoadedCount(in: modelContext)
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
