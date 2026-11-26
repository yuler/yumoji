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
            .japanese
        )
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .system, preferredLanguages: ["ja"]),
            .japanese
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
        XCTAssertEqual(
            ResolvedLanguage.resolve(preference: .japanese, preferredLanguages: ["en-US"]),
            .japanese
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
        let tables = try ["zh-Hans", "en", "ja"].map { code in
            try loadStrings("Localizable", language: code)
        }
        XCTAssertFalse(tables[0].isEmpty)
        XCTAssertEqual(Set(tables[0].keys), Set(tables[1].keys))
        XCTAssertEqual(Set(tables[0].keys), Set(tables[2].keys))
        for table in tables {
            for (key, value) in table {
                XCTAssertFalse(
                    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "Empty value for \(key)"
                )
            }
        }
    }

    func testInfoPlistLocalizationTablesExist() throws {
        for code in ["zh-Hans", "en", "ja"] {
            let table = try loadStrings("InfoPlist", language: code)
            XCTAssertFalse((table["NSCameraUsageDescription"] ?? "").isEmpty, code)
            XCTAssertFalse((table["NSPhotoLibraryAddUsageDescription"] ?? "").isEmpty, code)
        }
    }

    private func loadStrings(_ name: String, language: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            appBundle.url(forResource: name, withExtension: "strings", subdirectory: "\(language).lproj")
        )
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }
}
