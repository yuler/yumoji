import Foundation

enum InstallChannel: Equatable {
    case testFlight
    case appStore
}

struct AppVersionManifest: Equatable, Decodable {
    let version: String
    let build: Int
    let testflightUrl: String
    let appStoreUrl: String
    let appStoreVersion: String?

    init(
        version: String,
        build: Int,
        testflightUrl: String,
        appStoreUrl: String,
        appStoreVersion: String? = nil
    ) {
        self.version = version
        self.build = build
        self.testflightUrl = testflightUrl
        self.appStoreUrl = appStoreUrl
        self.appStoreVersion = appStoreVersion
    }
}

enum AppUpdate {
    static let endpoint = URL(string: "https://flightdeck.yuler.dev/v1/apps/yumoji/version.json")!

    enum CheckResult: Equatable {
        case upToDate
        case available(version: String, url: URL)
        case storeLinkMissing(version: String)
        case failed
    }

    static func marketingVersion(from raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "0.0.0" : trimmed
    }

    static func marketingVersion(bundle: Bundle = .main) -> String {
        marketingVersion(from: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    /// Production App Store receipts end in `receipt`. TestFlight uses `sandboxReceipt`.
    static func channel(receiptLastPathComponent: String?) -> InstallChannel {
        if receiptLastPathComponent == "receipt" {
            return .appStore
        }
        return .testFlight
    }

    static func channel(for bundle: Bundle = .main) -> InstallChannel {
        channel(receiptLastPathComponent: bundle.appStoreReceiptURL?.lastPathComponent)
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult? {
        guard let left = semverComponents(lhs), let right = semverComponents(rhs) else {
            return nil
        }
        for index in 0..<3 {
            if left[index] != right[index] {
                return left[index] < right[index] ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }

    static func installURL(channel: InstallChannel, manifest: AppVersionManifest) -> URL? {
        switch channel {
        case .testFlight:
            return URL(string: manifest.testflightUrl)
        case .appStore:
            let raw = manifest.appStoreUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            return URL(string: raw)
        }
    }

    static func latestVersion(channel: InstallChannel, manifest: AppVersionManifest) -> String? {
        switch channel {
        case .testFlight:
            return manifest.version
        case .appStore:
            guard let appStoreVersion = manifest.appStoreVersion else {
                return manifest.version
            }
            let trimmed = appStoreVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    static func evaluate(
        currentVersion: String,
        channel: InstallChannel,
        manifest: AppVersionManifest
    ) -> CheckResult {
        guard let targetVersion = latestVersion(channel: channel, manifest: manifest) else {
            return .upToDate
        }
        guard let order = compare(currentVersion, targetVersion) else {
            return .failed
        }
        guard order == .orderedAscending else {
            return .upToDate
        }
        guard let url = installURL(channel: channel, manifest: manifest) else {
            return .storeLinkMissing(version: targetVersion)
        }
        return .available(version: targetVersion, url: url)
    }

    private static func semverComponents(_ version: String) -> [Int]? {
        var raw = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("v") {
            raw.removeFirst()
        }
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let value = Int(part), value >= 0 else { return nil }
            numbers.append(value)
        }
        while numbers.count < 3 {
            numbers.append(0)
        }
        return numbers
    }
}

struct AppUpdateChecker {
    var endpoint: URL = AppUpdate.endpoint
    var session: URLSession = .shared

    func check(currentVersion: String, channel: InstallChannel) async -> AppUpdate.CheckResult {
        do {
            var request = URLRequest(
                url: endpoint,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return .failed
            }
            let manifest = try JSONDecoder().decode(AppVersionManifest.self, from: data)
            return AppUpdate.evaluate(
                currentVersion: currentVersion,
                channel: channel,
                manifest: manifest
            )
        } catch {
            return .failed
        }
    }
}
