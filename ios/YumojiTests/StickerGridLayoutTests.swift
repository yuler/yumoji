import XCTest
@testable import Yumoji

final class StickerGridLayoutTests: XCTestCase {
    private struct StubItem: Equatable {
        let id: String
        let date: Date
        let aspect: Double
    }

    func testGranularitySwitchesBetweenDayAndMonthByColumnCount() {
        XCTAssertEqual(StickerTimelineGranularity.forColumns(2), .day)
        XCTAssertEqual(StickerTimelineGranularity.forColumns(3), .day)
        XCTAssertEqual(StickerTimelineGranularity.forColumns(4), .month)
        XCTAssertEqual(StickerTimelineGranularity.forColumns(5), .month)
    }

    func testPinchSteppingRespectsMinAndMaxColumns() {
        XCTAssertEqual(StickerGridLayout.steppedColumns(current: 3, relativeMagnification: 1.3), 2)
        XCTAssertNil(StickerGridLayout.steppedColumns(current: 2, relativeMagnification: 1.5))

        XCTAssertEqual(StickerGridLayout.steppedColumns(current: 3, relativeMagnification: 0.75), 4)
        XCTAssertNil(StickerGridLayout.steppedColumns(current: 5, relativeMagnification: 0.6))

        XCTAssertNil(StickerGridLayout.steppedColumns(current: 3, relativeMagnification: 1.05))
    }

    func testGroupTimelineOrdersNewestFirstAndMergesForMonthGranularity() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
        }

        let items = [
            StubItem(id: "old-oct", date: makeDate(2026, 10, 5, 10), aspect: 1.0),
            StubItem(id: "nov-1-early", date: makeDate(2026, 11, 1, 9), aspect: 1.0),
            StubItem(id: "nov-1-late", date: makeDate(2026, 11, 1, 18), aspect: 1.0),
            StubItem(id: "nov-27", date: makeDate(2026, 11, 27, 12), aspect: 1.0)
        ]

        let daySections = StickerGridLayout.groupTimeline(
            items: items,
            granularity: .day,
            calendar: calendar,
            date: \.date,
            tieBreaker: { $0.id > $1.id }
        )
        XCTAssertEqual(daySections.map(\.id), ["2026-11-27", "2026-11-01", "2026-10-05"])
        XCTAssertEqual(daySections[1].items.map(\.id), ["nov-1-late", "nov-1-early"])

        let monthSections = StickerGridLayout.groupTimeline(
            items: items,
            granularity: .month,
            calendar: calendar,
            date: \.date,
            tieBreaker: { $0.id > $1.id }
        )
        XCTAssertEqual(monthSections.map(\.id), ["2026-11", "2026-10"])
        XCTAssertEqual(monthSections[0].items.map(\.id), ["nov-27", "nov-1-late", "nov-1-early"])
    }

    func testDistributeMasonryBalancesShortestColumnFirst() {
        let items = [
            StubItem(id: "tall", date: .now, aspect: 0.5),
            StubItem(id: "wide-1", date: .now, aspect: 2.0),
            StubItem(id: "wide-2", date: .now, aspect: 2.0),
            StubItem(id: "square", date: .now, aspect: 1.0)
        ]

        let columns = StickerGridLayout.distributeMasonry(
            items: items,
            columnCount: 2,
            aspectRatio: \.aspect
        )
        XCTAssertEqual(columns.count, 2)
        // First item (tall) goes into col 0; both wide items should stack into shorter col 1 before col 0 gets another.
        XCTAssertEqual(columns[0].first?.id, "tall")
        XCTAssertEqual(columns[1].prefix(2).map(\.id), ["wide-1", "wide-2"])
    }

    func testColumnPersistenceClampsValues() {
        let suiteName = "YumojiGridLayoutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(StickerGridLayout.loadSavedColumns(from: defaults), 3)

        StickerGridLayout.saveColumns(5, to: defaults)
        XCTAssertEqual(StickerGridLayout.loadSavedColumns(from: defaults), 5)

        StickerGridLayout.saveColumns(99, to: defaults)
        XCTAssertEqual(StickerGridLayout.loadSavedColumns(from: defaults), 5)

        StickerGridLayout.saveColumns(1, to: defaults)
        XCTAssertEqual(StickerGridLayout.loadSavedColumns(from: defaults), 2)
    }

    func testCardFrameDefaultsToHiddenAndPersistsPreference() {
        let suiteName = "YumojiGridFrameTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(StickerGridLayout.loadShowCardFrame(from: defaults))

        StickerGridLayout.saveShowCardFrame(true, to: defaults)
        XCTAssertTrue(StickerGridLayout.loadShowCardFrame(from: defaults))

        StickerGridLayout.saveShowCardFrame(false, to: defaults)
        XCTAssertFalse(StickerGridLayout.loadShowCardFrame(from: defaults))
    }

    func testRegularProfileSupportsWiderColumnRangeAndIndependentPersistence() {
        let suiteName = "YumojiGridRegularTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(StickerGridLayout.loadSavedColumns(for: .regular, from: defaults), 5)
        XCTAssertEqual(StickerTimelineGranularity.forColumns(4, profile: .regular), .day)
        XCTAssertEqual(StickerTimelineGranularity.forColumns(5, profile: .regular), .month)

        XCTAssertEqual(StickerGridLayout.steppedColumns(current: 5, relativeMagnification: 1.3, profile: .regular), 4)
        XCTAssertNil(StickerGridLayout.steppedColumns(current: 3, relativeMagnification: 1.5, profile: .regular))
        XCTAssertEqual(StickerGridLayout.steppedColumns(current: 7, relativeMagnification: 0.75, profile: .regular), 8)
        XCTAssertNil(StickerGridLayout.steppedColumns(current: 8, relativeMagnification: 0.6, profile: .regular))

        StickerGridLayout.saveColumns(7, for: .regular, to: defaults)
        StickerGridLayout.saveColumns(2, for: .compact, to: defaults)
        XCTAssertEqual(StickerGridLayout.loadSavedColumns(for: .regular, from: defaults), 7)
        XCTAssertEqual(StickerGridLayout.loadSavedColumns(for: .compact, from: defaults), 2)

        let columns = StickerGridLayout.distributeMasonry(
            items: (0..<10).map { StubItem(id: "\($0)", date: .now, aspect: 1.0) },
            columnCount: 6,
            profile: .regular,
            aspectRatio: \.aspect
        )
        XCTAssertEqual(columns.count, 6)
    }
}
