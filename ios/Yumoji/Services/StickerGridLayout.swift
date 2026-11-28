import CoreGraphics
import Foundation

/// Width class profile determining sensible column bounds and persistence keys.
enum GridLayoutProfile: Equatable, Sendable {
    /// iPhone and narrow iPad Split View / Slide Over.
    case compact
    /// Regular-width iPad layouts.
    case regular

    var minColumns: Int {
        switch self {
        case .compact: 2
        case .regular: 3
        }
    }

    var maxColumns: Int {
        switch self {
        case .compact: 5
        case .regular: 8
        }
    }

    var defaultColumns: Int {
        switch self {
        case .compact: 3
        case .regular: 5
        }
    }

    /// Maximum column count that still groups stickers by individual day.
    var dayMaxColumns: Int {
        switch self {
        case .compact: 3
        case .regular: 4
        }
    }

    var columnDefaultsKey: String {
        switch self {
        case .compact: "yumoji.grid.columnCount"
        case .regular: "yumoji.grid.columnCount.regular"
        }
    }
}

enum StickerTimelineGranularity: Equatable, Sendable {
    /// Year-Month-Day grouping used when zoomed in.
    case day
    /// Year-Month grouping used when zoomed out.
    case month

    static func forColumns(_ columnCount: Int, profile: GridLayoutProfile = .compact) -> StickerTimelineGranularity {
        columnCount <= profile.dayMaxColumns ? .day : .month
    }
}

struct StickerTimelineSection<Item>: Identifiable {
    let id: String
    let date: Date
    let granularity: StickerTimelineGranularity
    let items: [Item]
}

struct GridCardMetrics: Equatable, Sendable {
    let spacing: CGFloat
    let cornerRadius: CGFloat
    let contentPadding: CGFloat
}

/// Pure layout, timeline grouping, and pinch column stepping logic for the home waterfall grid.
enum StickerGridLayout {
    static let minColumns = 2
    static let maxColumns = 5
    static let defaultColumns = 3

    static let defaultShowCardFrame = false

    static let zoomInThreshold: CGFloat = 1.22
    static let zoomOutThreshold: CGFloat = 0.82

    private static let cardFrameDefaultsKey = "yumoji.grid.showCardFrame"

    static func clampColumns(_ count: Int, profile: GridLayoutProfile = .compact) -> Int {
        min(profile.maxColumns, max(profile.minColumns, count))
    }

    static func loadSavedColumns(
        for profile: GridLayoutProfile = .compact,
        from defaults: UserDefaults = .standard
    ) -> Int {
        guard defaults.object(forKey: profile.columnDefaultsKey) != nil else {
            return profile.defaultColumns
        }
        return clampColumns(defaults.integer(forKey: profile.columnDefaultsKey), profile: profile)
    }

    static func saveColumns(
        _ count: Int,
        for profile: GridLayoutProfile = .compact,
        to defaults: UserDefaults = .standard
    ) {
        defaults.set(clampColumns(count, profile: profile), forKey: profile.columnDefaultsKey)
    }

    static func loadShowCardFrame(from defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: cardFrameDefaultsKey) != nil else {
            return defaultShowCardFrame
        }
        return defaults.bool(forKey: cardFrameDefaultsKey)
    }

    static func saveShowCardFrame(_ show: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(show, forKey: cardFrameDefaultsKey)
    }

    /// Evaluates whether a pinch gesture relative magnification crosses the threshold
    /// to step to fewer (larger) or more (smaller) columns.
    static func steppedColumns(
        current: Int,
        relativeMagnification: CGFloat,
        profile: GridLayoutProfile = .compact
    ) -> Int? {
        let clampedCurrent = clampColumns(current, profile: profile)
        if relativeMagnification >= zoomInThreshold, clampedCurrent > profile.minColumns {
            return clampedCurrent - 1
        }
        if relativeMagnification <= zoomOutThreshold, clampedCurrent < profile.maxColumns {
            return clampedCurrent + 1
        }
        return nil
    }

    static func cardMetrics(for columnCount: Int) -> GridCardMetrics {
        switch columnCount {
        case ...2:
            return GridCardMetrics(spacing: 12, cornerRadius: 18, contentPadding: 12)
        case 3:
            return GridCardMetrics(spacing: 10, cornerRadius: 16, contentPadding: 9)
        case 4:
            return GridCardMetrics(spacing: 9, cornerRadius: 14, contentPadding: 7)
        case 5:
            return GridCardMetrics(spacing: 8, cornerRadius: 12, contentPadding: 6)
        case 6:
            return GridCardMetrics(spacing: 8, cornerRadius: 11, contentPadding: 5)
        default:
            return GridCardMetrics(spacing: 6, cornerRadius: 10, contentPadding: 4)
        }
    }

    /// Clamps sticker aspect ratios to pleasing waterfall card proportions.
    static func displayAspectRatio(for rawAspectRatio: Double) -> CGFloat {
        CGFloat(max(0.58, min(1.85, rawAspectRatio)))
    }

    /// Groups items in reverse-chronological order (newest first) by day or month.
    static func groupTimeline<Item>(
        items: [Item],
        granularity: StickerTimelineGranularity,
        calendar: Calendar = .current,
        date: (Item) -> Date,
        tieBreaker: (Item, Item) -> Bool
    ) -> [StickerTimelineSection<Item>] {
        let sorted = items.sorted { lhs, rhs in
            let lDate = date(lhs)
            let rDate = date(rhs)
            if lDate != rDate {
                return lDate > rDate
            }
            return tieBreaker(lhs, rhs)
        }

        var sections: [StickerTimelineSection<Item>] = []
        var sectionIndexByKey: [String: Int] = [:]

        for item in sorted {
            let itemDate = date(item)
            let (key, bucketDate) = sectionBucket(for: itemDate, granularity: granularity, calendar: calendar)
            if let existingIndex = sectionIndexByKey[key] {
                let existing = sections[existingIndex]
                sections[existingIndex] = StickerTimelineSection(
                    id: existing.id,
                    date: existing.date,
                    granularity: existing.granularity,
                    items: existing.items + [item]
                )
            } else {
                sectionIndexByKey[key] = sections.count
                sections.append(
                    StickerTimelineSection(
                        id: key,
                        date: bucketDate,
                        granularity: granularity,
                        items: [item]
                    )
                )
            }
        }
        return sections
    }

    /// Distributes items across `columnCount` columns using shortest-column-first masonry packing.
    static func distributeMasonry<Item>(
        items: [Item],
        columnCount: Int,
        profile: GridLayoutProfile = .compact,
        aspectRatio: (Item) -> Double
    ) -> [[Item]] {
        let count = clampColumns(columnCount, profile: profile)
        var columns = Array(repeating: [Item](), count: count)
        var heights = Array(repeating: 0.0, count: count)

        for item in items {
            let aspect = Double(displayAspectRatio(for: aspectRatio(item)))
            let estimatedHeight = (1.0 / aspect) + 0.16
            var shortestIndex = 0
            for index in 1..<count where heights[index] < heights[shortestIndex] {
                shortestIndex = index
            }
            columns[shortestIndex].append(item)
            heights[shortestIndex] += estimatedHeight
        }
        return columns
    }

    /// Localized section header title (e.g. `2026年11月27日` / `Nov 27, 2026` or `2026年11月` / `Nov 2026`).
    static func formatSectionTitle(
        for date: Date,
        granularity: StickerTimelineGranularity,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        switch granularity {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMM")
        }
        return formatter.string(from: date)
    }

    /// Short Year-Month pill text shown while scrolling the timeline.
    static func formatMonthIndicator(for date: Date, locale: Locale) -> String {
        formatSectionTitle(for: date, granularity: .month, locale: locale)
    }

    private static func sectionBucket(
        for date: Date,
        granularity: StickerTimelineGranularity,
        calendar: Calendar
    ) -> (String, Date) {
        switch granularity {
        case .day:
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            let d = comps.day ?? 0
            let bucketDate = calendar.date(from: comps) ?? date
            return (String(format: "%04d-%02d-%02d", y, m, d), bucketDate)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: date)
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            let bucketDate = calendar.date(from: comps) ?? date
            return (String(format: "%04d-%02d", y, m), bucketDate)
        }
    }
}
