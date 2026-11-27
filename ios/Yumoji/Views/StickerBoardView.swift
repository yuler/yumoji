import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 2D zoomable freeform sticker canvas with selection-first editing,
/// explicit place/save + Pin (bring to front), Fit-All centering, and persisted viewport.
@MainActor
struct StickerBoardView: View {
    let stickers: [StickerRecord]
    let placements: [BoardItemPlacement]
    let initialFocusStickerID: UUID?
    @Binding var selectedStickerID: UUID?
    let cameraAvailable: Bool
    let onOpenCamera: () -> Void
    let onPhoto: (PhotoInput) -> Void
    let onExportSticker: (UIImage) -> Void
    let onViewportCenterChanged: (CGPoint) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var lang

    @State private var viewport: BoardViewport = .identity
    @State private var canvasSize: CGSize = .zero
    @State private var didInitializeViewport = false

    @State private var panStartOffset: CGSize?
    @State private var zoomBaseViewport: BoardViewport?

    @State private var draftTransform: DraftStickerTransform?
    @State private var dragStartWorld: CGPoint?
    @State private var isDraggingSticker = false
    @State private var pinchBaseScale: Double?
    @State private var rotateBaseRadians: Double?
    @State private var isSnappedUpright = false

    @State private var pendingDelete: StickerRecord?
    @State private var showPhotosPicker = false
    @State private var pickerItem: PhotosPickerItem?

    private var placementByStickerID: [UUID: BoardItemPlacement] {
        Dictionary(uniqueKeysWithValues: placements.map { ($0.stickerID, $0) })
    }

    private var orderedItems: [(StickerRecord, BoardItemPlacement)] {
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
                InfiniteDotGridCanvas(viewport: viewport, viewportSize: size)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        guard selectedStickerID == nil else { return }
                        toggleFitOrReset(in: size)
                    }
                    .onTapGesture {
                        commitDraftAndDeselect()
                    }
                    .gesture(canvasPanGesture)

                if orderedItems.isEmpty {
                    emptyBoardHint
                } else {
                    ForEach(orderedItems, id: \.0.id) { record, placement in
                        let isSelected = record.id == selectedStickerID
                        let activeTransform = (isSelected ? draftTransform : nil)
                            ?? DraftStickerTransform(placement: placement)

                        BoardStickerItemView(
                            record: record,
                            transform: activeTransform,
                            viewport: viewport,
                            viewportSize: size,
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
                            }
                        )
                        .zIndex(Double(placement.zIndex) + (isSelected ? 0.5 : 0))
                    }
                }

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
            .clipped()
            .simultaneousGesture(twoFingerGesture(in: size))
            .onAppear {
                canvasSize = size
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
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickerItem, matching: .images)
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
        if dragStartWorld == nil {
            let current = draftTransform ?? DraftStickerTransform(placement: fallback)
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
        handleStickerDragChanged(translation: translation, fallback: fallback)
        dragStartWorld = nil
        isDraggingSticker = false
    }

    private func handleSelectedStickerTransformChanged(
        _ value: SimultaneousGesture<MagnifyGesture, RotateGesture>.Value
    ) {
        guard let selectedID = selectedStickerID,
              let placement = placementByStickerID[selectedID]
        else { return }

        if draftTransform == nil {
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

    // Floating bars & InfiniteDotGridCanvas live in Views/BoardControlsOverlay.swift.

    private var emptyBoardHint: some View {
        VStack(spacing: 10) {
            Text("✨")
                .font(.system(size: 46))
            Text(lang.t("board.empty.hint"))
                .font(YumojiTheme.rounded(15, weight: .medium))
                .foregroundStyle(YumojiTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Selection & Persistence

    private func selectSticker(_ record: StickerRecord) {
        if selectedStickerID == record.id {
            return
        }
        commitDraftIfNeeded()
        selectedStickerID = record.id
        if let placement = placementByStickerID[record.id] {
            draftTransform = DraftStickerTransform(placement: placement)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func syncDraftForCurrentSelection() {
        guard let selectedStickerID,
              let placement = placementByStickerID[selectedStickerID]
        else {
            draftTransform = nil
            return
        }
        if draftTransform == nil {
            draftTransform = DraftStickerTransform(placement: placement)
        }
    }

    private func commitDraftIfNeeded() {
        guard let selectedID = selectedStickerID,
              let draft = draftTransform,
              let placement = placementByStickerID[selectedID]
        else { return }
        placement.x = draft.x
        placement.y = draft.y
        placement.scale = draft.scale
        placement.rotation = draft.rotation
        placement.updatedAt = Date()
        try? modelContext.save()
    }

    private func commitDraftAndDeselect(haptic: Bool = false) {
        guard selectedStickerID != nil else { return }
        commitDraftIfNeeded()
        selectedStickerID = nil
        draftTransform = nil
        dragStartWorld = nil
        isDraggingSticker = false
        pinchBaseScale = nil
        rotateBaseRadians = nil
        isSnappedUpright = false
        if haptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func pinToFront(_ record: StickerRecord) {
        guard let placement = placementByStickerID[record.id] else { return }
        let maxZ = placements.map(\.zIndex).max() ?? 0
        if placement.zIndex < maxZ {
            placement.zIndex = maxZ + 1
            record.zIndex = maxZ + 1
            placement.updatedAt = Date()
            try? modelContext.save()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteSticker(_ record: StickerRecord) {
        if selectedStickerID == record.id {
            selectedStickerID = nil
            draftTransform = nil
        }
        try? StickerStorage.delete(record, in: modelContext)
    }

    // MARK: - Viewport Helpers

    private func initializeViewportIfNeeded(size: CGSize) {
        guard !didInitializeViewport, size.width > 1, size.height > 1 else { return }
        didInitializeViewport = true

        if let focusID = initialFocusStickerID,
           let placement = placementByStickerID[focusID] {
            viewport = BoardCanvasMath.focus(
                on: CGPoint(x: placement.x, y: placement.y),
                zoom: 1.0
            )
            selectedStickerID = focusID
            draftTransform = DraftStickerTransform(placement: placement)
            reportViewportCenter()
            return
        }

        if let saved = StickerStorage.loadBoardViewport(in: modelContext) {
            viewport = saved
            reportViewportCenter()
            return
        }

        fitAllStickers(in: size, animated: false)
    }

    private func fitAllStickers(in size: CGSize, animated: Bool) {
        let geometries = orderedItems.map { record, placement in
            BoardItemGeometry(
                x: placement.x,
                y: placement.y,
                scale: placement.scale,
                aspectRatio: record.aspectRatio
            )
        }
        let target = BoardCanvasMath.fitAll(items: geometries, viewportSize: size)
        applyViewport(target, animated: animated)
    }

    private func resetZoomTo100(in size: CGSize) {
        let geometries = orderedItems.map { record, placement in
            BoardItemGeometry(
                x: placement.x,
                y: placement.y,
                scale: placement.scale,
                aspectRatio: record.aspectRatio
            )
        }
        let fit = BoardCanvasMath.fitAll(items: geometries, viewportSize: size)
        let contentCenter = BoardCanvasMath.visibleWorldCenter(viewport: fit)
        applyViewport(BoardCanvasMath.focus(on: contentCenter, zoom: 1.0), animated: true)
    }

    private func toggleFitOrReset(in size: CGSize) {
        if abs(viewport.zoom - 1.0) < 0.08 {
            fitAllStickers(in: size, animated: true)
        } else {
            resetZoomTo100(in: size)
        }
    }

    private func applyViewport(_ target: BoardViewport, animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                viewport = target
            }
        } else {
            viewport = target
        }
        reportViewportCenter()
        StickerStorage.saveBoardViewport(target, in: modelContext)
    }

    private func reportViewportCenter() {
        onViewportCenterChanged(BoardCanvasMath.visibleWorldCenter(viewport: viewport))
    }
}
