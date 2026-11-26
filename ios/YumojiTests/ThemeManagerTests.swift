import SwiftUI
import XCTest
@testable import Yumoji

@MainActor
final class ThemeManagerTests: XCTestCase {
    func testThemeModePreferredColorSchemeMapping() {
        XCTAssertNil(ThemeMode.system.preferredColorScheme)
        XCTAssertEqual(ThemeMode.light.preferredColorScheme, .light)
        XCTAssertEqual(ThemeMode.dark.preferredColorScheme, .dark)
    }

    func testResolvedColorSchemeIsConcreteForSheets() {
        XCTAssertEqual(ThemeMode.system.resolved(against: .light), .light)
        XCTAssertEqual(ThemeMode.system.resolved(against: .dark), .dark)
        XCTAssertEqual(ThemeMode.light.resolved(against: .dark), .light)
        XCTAssertEqual(ThemeMode.dark.resolved(against: .light), .dark)
    }

    func testDefaultsToSystemAndPersistsSelection() {
        let suiteName = "cc.yuler.yumoji.tests.theme.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = ThemeManager(defaults: defaults)
        XCTAssertEqual(first.selection, .system)

        first.selection = .dark
        XCTAssertEqual(defaults.string(forKey: ThemeManager.storageKey), ThemeMode.dark.rawValue)

        let restoredDark = ThemeManager(defaults: defaults)
        XCTAssertEqual(restoredDark.selection, .dark)

        restoredDark.selection = .light
        let restoredLight = ThemeManager(defaults: defaults)
        XCTAssertEqual(restoredLight.selection, .light)
    }

    func testInvalidStoredValueFallsBackToSystem() {
        let suiteName = "cc.yuler.yumoji.tests.theme.invalid.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("neon-pink", forKey: ThemeManager.storageKey)
        let manager = ThemeManager(defaults: defaults)
        XCTAssertEqual(manager.selection, .system)
    }
}
