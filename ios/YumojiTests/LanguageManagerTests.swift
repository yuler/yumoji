import XCTest
@testable import Yumoji

@MainActor
final class LanguageManagerTests: XCTestCase {
    private var appBundle: Bundle {
        Bundle(for: LanguageManager.self)
    }

    func testSystemLanguageResolution() {
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: ["zh-Hans-CN"]),
            .zhHans
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: ["zh-Hant-TW"]),
            .zhHans
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: ["zh-HK"]),
            .zhHans
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: ["zh"]),
            .zhHans
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: ["en-US"]),
            .english
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: ["ja-JP", "zh-Hans-CN"]),
            .english
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: ["fr-FR"]),
            .english
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: []),
            .english
        )
    }

    func testExplicitLanguageOverridesSystem() {
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .english, preferredLanguages: ["zh-Hans-CN"]),
            .english
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .zhHans, preferredLanguages: ["en-US"]),
            .zhHans
        )
    }

    func testLanguageManagerDefaultsToSystemAndPersistsSelection() {
        let suiteName = "cc.yuler.yumoji.tests.lang.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = LanguageManager(
            defaults: defaults,
            preferredLanguages: ["en-US"],
            baseBundle: appBundle
        )
        XCTAssertEqual(first.selection, .system)
        XCTAssertEqual(first.resolved, .english)
        XCTAssertEqual(first.t("settings.title"), "Settings")

        first.selection = .zhHans
        XCTAssertEqual(first.resolved, .zhHans)
        XCTAssertEqual(first.t("settings.title"), "设置")

        let restored = LanguageManager(
            defaults: defaults,
            preferredLanguages: ["en-US"],
            baseBundle: appBundle
        )
        XCTAssertEqual(restored.selection, .zhHans)
        XCTAssertEqual(restored.resolved, .zhHans)

        restored.selection = .system
        restored.refreshSystemLanguages(["zh-Hant-TW"])
        XCTAssertEqual(restored.resolved, .zhHans)
        restored.refreshSystemLanguages(["de-DE"])
        XCTAssertEqual(restored.resolved, .english)
    }

    func testStringsTablesExistAndHaveMatchingKeys() throws {
        let zhURL = try XCTUnwrap(
            appBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: "zh-Hans.lproj")
        )
        let enURL = try XCTUnwrap(
            appBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: "en.lproj")
        )

        let zhDict = try XCTUnwrap(NSDictionary(contentsOf: zhURL) as? [String: String])
        let enDict = try XCTUnwrap(NSDictionary(contentsOf: enURL) as? [String: String])

        XCTAssertFalse(zhDict.isEmpty)
        XCTAssertEqual(Set(zhDict.keys), Set(enDict.keys))

        for (key, value) in zhDict {
            XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty zh value for \(key)")
        }
        for (key, value) in enDict {
            XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty en value for \(key)")
        }
    }

    func testInfoPlistLocalizationTablesExist() throws {
        let zhURL = try XCTUnwrap(
            appBundle.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: "zh-Hans.lproj")
        )
        let enURL = try XCTUnwrap(
            appBundle.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: "en.lproj")
        )

        let zhDict = try XCTUnwrap(NSDictionary(contentsOf: zhURL) as? [String: String])
        let enDict = try XCTUnwrap(NSDictionary(contentsOf: enURL) as? [String: String])

        XCTAssertFalse((zhDict["NSCameraUsageDescription"] ?? "").isEmpty)
        XCTAssertFalse((enDict["NSCameraUsageDescription"] ?? "").isEmpty)
    }
}
