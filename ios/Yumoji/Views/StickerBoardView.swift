import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 2D zoomable freeform sticker canvas with selection-first editing,
/// explicit place/save + Pin (bring to front), Fit-All centering, and persisted viewport.
@MainActor
struct StickerBoardView: View {
    static let canvasCoordinateSpaceName = "BoardCanvasSpace"

    let initialFocusStickerID: UUID?
    @Binding var selectedStickerID: UUID?
    let cameraAvailable: Bool
    let onOpenCamera: () -> Void
    let onPhoto: (PhotoInput) -> Void
    let onExportSticker: (UIImage) -> Void
    let onViewportCenterChanged: (CGPoint) -> Void
    var onStickersMutated: () -> Void = {}

    @Environment(\.modelContext) var modelContext
    @Environment(LanguageManager.self) private var lang

    @Query(sort: \StickerRecord.createdAt, order: .reverse) var stickers: [StickerRecord]
    @Query var allPlacements: [BoardItemPlacement]

    @State var viewport: BoardViewport = .identity
    @State var canvasSize: CGSize = .zero
    @State var didInitializeViewport = false

    @State private var panStartOffset: CGSize?
    @State private var zoomBaseViewport: BoardViewport?

    @State var draftStickerID: UUID?
    @State var draftTransform: DraftStickerTransform?
    @State var dragStartWorld: CGPoint?
    @State var isDraggingSticker = false
    @State var isTwoFingerTransforming = false
    @State var pinchBaseScale: Double?
    @State var rotateBaseRadians: Double?
    @State var isSnappedUpright = false

    @State private var pendingDelete: StickerRecord?
    @State private var showPhotosPicker = false
    @State private var pickerItem: PhotosPickerItem?

    var placements: [BoardItemPlacement] {
        allPlacements.filter { $0.boardID == StickerRecord.defaultBoardID }
    }

    var placementByStickerID: [UUID: BoardItemPlacement] {
        Dictionary(uniqueKeysWithValues: placements.map { ($0.stickerID, $0) })
    }

    var orderedItems: [(StickerRecord, BoardItemPlacement)] {
        let lookup = placementByStickerID
        return stickers
            .compactMap { record in
                lookup[record.id].map { (record, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.1.zIndex != rhs.1.zIndex {
                    return lhs.1.zIndex < rhs.1.zIndex
                }
                return lhs.0.createdAt < rhs.0.createdAt
            }
    }

    private var selectedRecord: StickerRecord? {
        guard let selectedStickerID else { return nil }
        return stickers.first { $0.id == selectedStickerID }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .bottom) {
                // Keep canvas + stickers in their own ZStack so sticker zIndex values
                // stay scoped to the canvas and can never overlap the bottom toolbar.
                ZStack {
                    InfiniteDotGridCanvas(viewport: viewport, viewportSize: size)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            guard selectedStickerID == nil else { return }
                            toggleFitOrReset(in: size)
                        }
                        .onTapGesture {
                            commitDraftAndDeselect()
                        }

                    if orderedItems.isEmpty {
                        BoardEmptyHint()
                    } else {
                        ForEach(orderedItems, id: \.0.id) { record, placement in
                            let isSelected = record.id == selectedStickerID
                            let activeTransform = (isSelected && draftStickerID == record.id ? draftTransform : nil)
                                ?? DraftStickerTransform(placement: placement)

                            BoardStickerItemView(
                                record: record,
                                transform: activeTransform,
                                viewport: viewport,
                                viewportSize: size,
                                canvasCoordinateSpace: Self.canvasCoordinateSpaceName,
                                isSelected: isSelected,
                                isDragging: isSelected && isDraggingSticker,
                                isSnappedUpright: isSelected && isSnappedUpright,
                                onTap: {
                                    selectSticker(record)
                                },
                                onDragChanged: { translation in
                                    handleStickerDragChanged(translation: translation, fallback: placement)
                                },
                                onDragEnded: { translation in
                                    handleStickerDragEnded(translation: translation, fallback: placement)
                                },
                                onHandleTransformChanged: { center, startPoint, currentPoint in
                                    handleCornerTransformChanged(
                                        center: center,
                                        startPoint: startPoint,
                                        currentPoint: currentPoint,
                                        fallback: placement
                                    )
                                },
                                onHandleTransformEnded: {
                                    handleCornerTransformEnded()
                                }
                            )
                            .zIndex(Double(placement.zIndex) + (isSelected ? 0.5 : 0))
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                .coordinateSpace(name: Self.canvasCoordinateSpaceName)
                .clipped()
                .gesture(canvasPanGesture)
                .simultaneousGesture(twoFingerGesture(in: size))

                VStack(spacing: 10) {
                    if let active = selectedRecord {
                        BoardSelectedActionBar(
                            onPin: { pinToFront(active) },
                            onExport: {
                                commitDraftIfNeeded()
                                if let image = StickerThumbnailCache.shared.fullResolutionImage(for: active) {
                                    onExportSticker(image)
                                }
                            },
                            onDelete: { pendingDelete = active },
                            onPlace: { commitDraftAndDeselect(haptic: true) }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        BoardUnselectedControls(
                            zoom: viewport.zoom,
                            cameraAvailable: cameraAvailable,
                            onFitAll: { fitAllStickers(in: size, animated: true) },
                            onResetZoom: { resetZoomTo100(in: size) },
                            onZoomIn: { stepCanvasZoom(.zoomIn, in: size) },
                            onZoomOut: { stepCanvasZoom(.zoomOut, in: size) },
                            onOpenCamera: onOpenCamera,
                            onOpenPhotosPicker: { showPhotosPicker = true }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: selectedStickerID)
            }
            .frame(width: size.width, height: size.height)
            .onAppear {
                canvasSize = size
                StickerStorage.ensureBoardPlacements(for: stickers, in: modelContext)
                initializeViewportIfNeeded(size: size)
                syncDraftForCurrentSelection()
                reportViewportCenter()
            }
            .onChange(of: size) { _, newSize in
                canvasSize = newSize
                initializeViewportIfNeeded(size: newSize)
            }
        }
        .background(YumojiTheme.cream.ignoresSafeArea())
        .background {
            BoardKeyboardShortcutsView(
                hasSelection: selectedRecord != nil,
                onEscape: { commitDraftAndDeselect() },
                onDeleteSelected: {
                    if let active = selectedRecord {
                        pendingDelete = active
                    }
                },
                onFitAll: { fitAllStickers(in: canvasSize, animated: true) },
                onResetZoom: { resetZoomTo100(in: canvasSize) },
                onZoomIn: { stepCanvasZoom(.zoomIn, in: canvasSize) },
                onZoomOut: { stepCanvasZoom(.zoomOut, in: canvasSize) }
            )
        }
        .yumojiImageDropTarget { data in
            onPhoto(.dropped(data))
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickerItem, matching: .images)
        .onChange(of: initialFocusStickerID) { _, newFocusID in
            guard let focusID = newFocusID,
                  let placement = placementByStickerID[focusID]
            else { return }
            applyViewport(BoardCanvasMath.focus(on: CGPoint(x: placement.x, y: placement.y), zoom: 1.0), animated: true)
            selectedStickerID = focusID
            draftStickerID = focusID
            draftTransform = DraftStickerTransform(placement: placement)
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            pickerItem = nil
            onPhoto(.library(newItem))
        }
        .onChange(of: selectedStickerID) { _, _ in
            syncDraftForCurrentSelection()
        }
        .onChange(of: placements.count) { _, _ in
            syncDraftForCurrentSelection()
        }
        .onDisappear {
            commitDraftIfNeeded()
            StickerStorage.saveBoardViewport(viewport, in: modelContext)
        }
        .confirmationDialog(
            lang.t("board.delete.confirm.title"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(lang.t("board.delete.confirm.action"), role: .destructive) {
                if let target = pendingDelete {
                    deleteSticker(target)
                }
                pendingDelete = nil
            }
            Button(lang.t("board.delete.confirm.cancel"), role: .cancel) {
                pendingDelete = nil
            }
        }
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if panStartOffset == nil {
                    panStartOffset = viewport.offset
                }
                let start = panStartOffset ?? viewport.offset
                viewport.offset = CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                )
            }
            .onEnded { _ in
                panStartOffset = nil
                reportViewportCenter()
                StickerStorage.saveBoardViewport(viewport, in: modelContext)
            }
    }

    private func twoFingerGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .simultaneously(with: RotateGesture())
            .onChanged { value in
                isTwoFingerTransforming = true
                if selectedStickerID != nil {
                    handleSelectedStickerTransformChanged(value)
                } else if let mag = value.first {
                    if zoomBaseViewport == nil {
                        zoomBaseViewport = viewport
                    }
                    let base = zoomBaseViewport ?? viewport
                    let anchor = CGPoint(
                        x: mag.startAnchor.x * size.width,
                        y: mag.startAnchor.y * size.height
                    )
                    viewport = BoardCanvasMath.zoomedViewport(
                        from: base,
                        magnification: mag.magnification,
                        anchor: anchor,
                        viewportSize: size
                    )
                }
            }
            .onEnded { _ in
                isTwoFingerTransforming = false
                if selectedStickerID != nil {
                    pinchBaseScale = nil
                    rotateBaseRadians = nil
                    isSnappedUpright = false
                } else {
                    zoomBaseViewport = nil
                    reportViewportCenter()
                    StickerStorage.saveBoardViewport(viewport, in: modelContext)
                }
            }
    }

    private func handleStickerDragChanged(translation: CGSize, fallback: BoardItemPlacement) {
        guard !isTwoFingerTransforming else { return }
        if dragStartWorld == nil {
            let current = (draftStickerID == fallback.stickerID ? draftTransform : nil)
                ?? DraftStickerTransform(placement: fallback)
            draftStickerID = fallback.stickerID
            draftTransform = current
            dragStartWorld = CGPoint(x: current.x, y: current.y)
            isDraggingSticker = true
        }
        guard let start = dragStartWorld else { return }
        let safeZoom = max(viewport.zoom, 0.01)
        draftTransform?.x = Double(start.x + translation.width / safeZoom)
        draftTransform?.y = Double(start.y + translation.height / safeZoom)
    }

    private func handleStickerDragEnded(translation: CGSize, fallback: BoardItemPlacement) {
        if !isTwoFingerTransforming {
            handleStickerDragChanged(translation: translation, fallback: fallback)
        }
        dragStartWorld = nil
        isDraggingSticker = false
    }

    private func handleSelectedStickerTransformChanged(
        _ value: SimultaneousGesture<MagnifyGesture, RotateGesture>.Value
    ) {
        guard let selectedID = selectedStickerID,
              let placement = placementByStickerID[selectedID]
        else { return }

        if draftTransform == nil || draftStickerID != selectedID {
            draftStickerID = selectedID
            draftTransform = DraftStickerTransform(placement: placement)
        }
        guard var draft = draftTransform else { return }

        if let mag = value.first {
            if pinchBaseScale == nil {
                pinchBaseScale = draft.scale
            }
            let base = pinchBaseScale ?? draft.scale
            draft.scale = BoardCanvasMath.clampStickerScale(base * Double(mag.magnification))
        }

        if let rot = value.second {
            if rotateBaseRadians == nil {
                rotateBaseRadians = draft.rotation
            }
            let base = rotateBaseRadians ?? draft.rotation
            let raw = base + rot.rotation.radians
            let snap = BoardCanvasMath.snapRotation(raw)
            if snap.snapped && !isSnappedUpright {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            isSnappedUpright = snap.snapped
            draft.rotation = snap.radians
        }

        draftTransform = draft
    }

    private func handleCornerTransformChanged(
        center: CGPoint,
        startPoint: CGPoint,
        currentPoint: CGPoint,
        fallback: BoardItemPlacement
    ) {
        if draftTransform == nil || draftStickerID != fallback.stickerID {
            draftStickerID = fallback.stickerID
            draftTransform = DraftStickerTransform(placement: fallback)
        }
        guard var draft = draftTransform else { return }
        if pinchBaseScale == nil {
            pinchBaseScale = draft.scale
        }
        if rotateBaseRadians == nil {
            rotateBaseRadians = draft.rotation
        }
        let result = BoardCanvasMath.handleTransform(
            center: center,
            startPoint: startPoint,
            currentPoint: currentPoint,
            baseScale: pinchBaseScale ?? draft.scale,
            baseRotation: rotateBaseRadians ?? draft.rotation
        )
        if result.snappedUpright && !isSnappedUpright {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        isSnappedUpright = result.snappedUpright
        draft.scale = result.scale
        draft.rotation = result.rotation
        draftTransform = draft
    }

    private func handleCornerTransformEnded() {
        pinchBaseScale = nil
        rotateBaseRadians = nil
        isSnappedUpright = false
    }

    private func stepCanvasZoom(_ direction: BoardZoomDirection, in size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let targetZoom = BoardCanvasMath.steppedCanvasZoom(from: viewport.zoom, direction: direction)
        let magnification = targetZoom / max(viewport.zoom, 0.01)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let next = BoardCanvasMath.zoomedViewport(
            from: viewport,
            magnification: magnification,
            anchor: center,
            viewportSize: size
        )
        applyViewport(next, animated: true)
    }

    // Floating bars, keyboard shortcuts & InfiniteDotGridCanvas live in Views/BoardControlsOverlay.swift.
    // Selection, persistence & viewport helpers live in Views/StickerBoardView+Viewport.swift.
}
