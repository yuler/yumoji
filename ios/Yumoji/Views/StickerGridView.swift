import PhotosUI
import SwiftUI
import UIKit

/// Default home screen when stickers exist: reverse-chronological masonry waterfall
/// with pinch-to-resize (2–5 columns) and granularity-linked timeline headers.
@MainActor
struct StickerGridView: View {
    let stickers: [StickerRecord]
    let cameraAvailable: Bool
    let onOpenCamera: () -> Void
    let onPhoto: (PhotoInput) -> Void
    let onSelectSticker: (StickerRecord) -> Void

    @Environment(LanguageManager.self) private var lang

    @State private var columnCount: Int = StickerGridLayout.loadSavedColumns()
    @State private var pickerItem: PhotosPickerItem?
    @State private var pinchAnchorScale: CGFloat = 1.0
    @State private var liveRubberBand: CGFloat = 1.0
    @State private var visibleMonthLabel: String = ""
    @State private var showScrollIndicator = false
    @State private var hideIndicatorTask: Task<Void, Never>?
    @State private var lastTopOffset: CGFloat?

    private var granularity: StickerTimelineGranularity {
        StickerTimelineGranularity.forColumns(columnCount)
    }

    private var sections: [StickerTimelineSection<StickerRecord>] {
        StickerGridLayout.groupTimeline(
            items: stickers,
            granularity: granularity,
            date: \.effectiveDate,
            tieBreaker: { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id.uuidString > rhs.id.uuidString
            }
        )
    }

    var body: some View {
        let metrics = StickerGridLayout.cardMetrics(for: columnCount)

        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            MasonrySectionGrid(
                                stickers: section.items,
                                columnCount: columnCount,
                                metrics: metrics,
                                onTap: onSelectSticker
                            )
                            .padding(.horizontal, 14)
                        } header: {
                            sectionHeader(section)
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 112)
                .scaleEffect(liveRubberBand, anchor: .center)
                .animation(.spring(response: 0.3, dampingFraction: 0.84), value: columnCount)
            }
            .coordinateSpace(name: "StickerGridScroll")
            .simultaneousGesture(pinchGesture)
            .onPreferenceChange(GridSectionPositionKey.self) { positions in
                updateVisibleMonth(from: positions)
            }

            if showScrollIndicator, !visibleMonthLabel.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Text(visibleMonthLabel)
                            .font(YumojiTheme.rounded(12, weight: .semibold))
                            .foregroundStyle(YumojiTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(YumojiTheme.card.opacity(0.95), in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(YumojiTheme.ink.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: YumojiTheme.shadow.opacity(0.55), radius: 8, y: 3)
                            .padding(.trailing, 14)
                            .padding(.top, 10)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }

            bottomDock
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .background(YumojiTheme.cream.ignoresSafeArea())
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            pickerItem = nil
            onPhoto(.library(newItem))
        }
        .onChange(of: columnCount) { _, newValue in
            StickerGridLayout.saveColumns(newValue)
        }
        .onDisappear {
            hideIndicatorTask?.cancel()
        }
    }

    private func sectionHeader(_ section: StickerTimelineSection<StickerRecord>) -> some View {
        HStack(spacing: 8) {
            Text(
                StickerGridLayout.formatSectionTitle(
                    for: section.date,
                    granularity: section.granularity,
                    locale: lang.locale
                )
            )
            .font(YumojiTheme.rounded(15, weight: .bold))
            .foregroundStyle(YumojiTheme.ink)

            Text("\(section.items.count)")
                .font(YumojiTheme.rounded(12, weight: .semibold))
                .foregroundStyle(YumojiTheme.inkSoft)
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(YumojiTheme.surfaceSecondary.opacity(0.85), in: Capsule())

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(YumojiTheme.cream.opacity(0.94))
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: GridSectionPositionKey.self,
                    value: [
                        GridSectionPosition(
                            id: section.id,
                            date: section.date,
                            minY: proxy.frame(in: .named("StickerGridScroll")).minY
                        )
                    ]
                )
            }
        }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let relative = value.magnification / max(pinchAnchorScale, 0.01)
                if let next = StickerGridLayout.steppedColumns(
                    current: columnCount,
                    relativeMagnification: relative
                ) {
                    pinchAnchorScale = value.magnification
                    liveRubberBand = 1.0
                    let haptic = UIImpactFeedbackGenerator(style: .light)
                    haptic.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        columnCount = next
                    }
                } else {
                    let delta = (relative - 1.0) * 0.22
                    liveRubberBand = min(1.05, max(0.95, 1.0 + delta))
                }
            }
            .onEnded { _ in
                pinchAnchorScale = 1.0
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    liveRubberBand = 1.0
                }
            }
    }

    private var bottomDock: some View {
        HStack(spacing: 10) {
            Button {
                onOpenCamera()
            } label: {
                Label(lang.t("home.take_photo"), systemImage: "camera.fill")
                    .font(YumojiTheme.rounded(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(YumojiTheme.accent, in: Capsule())
            }
            .disabled(!cameraAvailable)
            .opacity(cameraAvailable ? 1 : 0.45)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(lang.t("home.pick_from_library"), systemImage: "photo.on.rectangle")
                    .font(YumojiTheme.rounded(15, weight: .semibold))
                    .foregroundStyle(YumojiTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(YumojiTheme.card, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(YumojiTheme.ink.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .shadow(color: YumojiTheme.shadow.opacity(0.65), radius: 10, y: 4)
    }

    private func updateVisibleMonth(from positions: [GridSectionPosition]) {
        guard !positions.isEmpty else { return }
        let sorted = positions.sorted { $0.minY < $1.minY }
        let topSection = sorted.last(where: { $0.minY <= 28 }) ?? sorted.first!
        let nextLabel = StickerGridLayout.formatMonthIndicator(for: topSection.date, locale: lang.locale)
        let firstY = sorted.first?.minY ?? 0

        defer { lastTopOffset = firstY }
        visibleMonthLabel = nextLabel

        guard let previous = lastTopOffset, abs(firstY - previous) > 4 else {
            return
        }
        guard sections.count > 1 else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            showScrollIndicator = true
        }
        hideIndicatorTask?.cancel()
        hideIndicatorTask = Task {
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showScrollIndicator = false
            }
        }
    }
}

/// Shortest-column-first masonry grid for a single timeline section.
@MainActor
private struct MasonrySectionGrid: View {
    let stickers: [StickerRecord]
    let columnCount: Int
    let metrics: GridCardMetrics
    let onTap: (StickerRecord) -> Void

    var body: some View {
        let columns = StickerGridLayout.distributeMasonry(
            items: stickers,
            columnCount: columnCount,
            aspectRatio: \.aspectRatio
        )

        HStack(alignment: .top, spacing: metrics.spacing) {
            ForEach(0..<columns.count, id: \.self) { columnIndex in
                LazyVStack(spacing: metrics.spacing) {
                    ForEach(columns[columnIndex]) { record in
                        StickerGridCardView(
                            record: record,
                            metrics: metrics,
                            onTap: { onTap(record) }
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

@MainActor
private struct StickerGridCardView: View {
    let record: StickerRecord
    let metrics: GridCardMetrics
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        let displayAspect = StickerGridLayout.displayAspectRatio(for: record.aspectRatio)
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)

        Button(action: onTap) {
            ZStack {
                shape
                    .fill(YumojiTheme.card.opacity(0.92))

                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(metrics.contentPadding)
                        .shadow(color: YumojiTheme.shadow.opacity(0.45), radius: 5, y: 2)
                } else {
                    ProgressView()
                        .tint(YumojiTheme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(displayAspect, contentMode: .fit)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(YumojiTheme.ink.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: YumojiTheme.shadow.opacity(0.32), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .task(id: record.id) {
            if thumbnail == nil {
                thumbnail = StickerThumbnailCache.shared.thumbnail(for: record)
            }
        }
    }
}

private struct GridSectionPosition: Equatable {
    let id: String
    let date: Date
    let minY: CGFloat
}

private struct GridSectionPositionKey: PreferenceKey {
    static var defaultValue: [GridSectionPosition] = []
    static func reduce(value: inout [GridSectionPosition], nextValue: () -> [GridSectionPosition]) {
        value.append(contentsOf: nextValue())
    }
}
