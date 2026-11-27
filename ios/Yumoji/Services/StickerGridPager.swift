import Foundation
import Observation
import SwiftData

/// Manages paginated loading of `StickerRecord` pages for the home waterfall grid.
@MainActor
@Observable
final class StickerGridPager {
    static let defaultPageSize = 30

    let pageSize: Int
    private(set) var items: [StickerRecord] = []
    private(set) var totalCount: Int = 0
    private(set) var isLoading = false
    private(set) var hasLoadedInitial = false

    var hasMore: Bool {
        items.count < totalCount
    }

    init(pageSize: Int = StickerGridPager.defaultPageSize) {
        self.pageSize = max(1, pageSize)
    }

    func loadInitialIfNeeded(in context: ModelContext) {
        guard !hasLoadedInitial else { return }
        reload(in: context, targetCount: pageSize)
    }

    func loadNextPage(in context: ModelContext) {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        totalCount = StickerStorage.fetchStickerCount(in: context)
        guard items.count < totalCount else { return }

        let fetched = StickerStorage.fetchStickerPage(
            offset: items.count,
            limit: pageSize,
            in: context
        )
        guard !fetched.isEmpty else { return }

        let existingIDs = Set(items.map(\.id))
        let uniqueNew = fetched.filter { !existingIDs.contains($0.id) }
        items.append(contentsOf: uniqueNew)
    }

    func reloadPreservingLoadedCount(in context: ModelContext) {
        let target = max(pageSize, items.count)
        reload(in: context, targetCount: target)
    }

    func reset() {
        items = []
        totalCount = 0
        isLoading = false
        hasLoadedInitial = false
    }

    private func reload(in context: ModelContext, targetCount: Int) {
        isLoading = true
        defer {
            isLoading = false
            hasLoadedInitial = true
        }

        totalCount = StickerStorage.fetchStickerCount(in: context)
        guard totalCount > 0 else {
            items = []
            return
        }

        let limit = min(totalCount, max(pageSize, targetCount))
        items = StickerStorage.fetchStickerPage(offset: 0, limit: limit, in: context)
    }
}
