import XCTest
@testable import Yumoji

final class AppUpdateTests: XCTestCase {
    private let manifest = AppVersionManifest(
        version: "0.0.4",
        build: 4,
        testflightUrl: "https://testflight.apple.com/join/YumojiTest",
        appStoreUrl: "https://apps.apple.com/app/id123"
    )

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testEndpointTargetsYumojiFlightdeckManifest() {
        XCTAssertEqual(
            AppUpdate.endpoint.absoluteString,
            "https://flightdeck.yuler.dev/v1/apps/yumoji/version.json"
        )
    }

    func testMarketingVersionNormalization() {
        XCTAssertEqual(AppUpdate.marketingVersion(from: "1.2.3"), "1.2.3")
        XCTAssertEqual(AppUpdate.marketingVersion(from: " 1.2.3 \n"), "1.2.3")
        XCTAssertEqual(AppUpdate.marketingVersion(from: ""), "0.0.0")
        XCTAssertEqual(AppUpdate.marketingVersion(from: "   "), "0.0.0")
        XCTAssertEqual(AppUpdate.marketingVersion(from: nil), "0.0.0")
        XCTAssertFalse(AppUpdate.marketingVersion(bundle: Bundle(for: LanguageManager.self)).isEmpty)
    }

    func testCompareSemver() {
        XCTAssertEqual(AppUpdate.compare("0.0.3", "0.0.4"), .orderedAscending)
        XCTAssertEqual(AppUpdate.compare("0.0.4", "0.0.4"), .orderedSame)
        XCTAssertEqual(AppUpdate.compare("0.1.0", "0.0.9"), .orderedDescending)
        XCTAssertEqual(AppUpdate.compare("v1.2", "1.2.0"), .orderedSame)
        XCTAssertNil(AppUpdate.compare("nope", "1.0.0"))
    }

    func testChannelUsesProductionReceiptOnlyForAppStore() {
        XCTAssertEqual(AppUpdate.channel(receiptLastPathComponent: "receipt"), .appStore)
        XCTAssertEqual(AppUpdate.channel(receiptLastPathComponent: "sandboxReceipt"), .testFlight)
        XCTAssertEqual(AppUpdate.channel(receiptLastPathComponent: nil), .testFlight)
    }

    func testEvaluateRoutesTestFlightAndAppStore() {
        let testFlight = AppUpdate.evaluate(
            currentVersion: "0.0.3",
            channel: .testFlight,
            manifest: manifest
        )
        XCTAssertEqual(
            testFlight,
            .available(version: "0.0.4", url: URL(string: manifest.testflightUrl)!)
        )

        let appStore = AppUpdate.evaluate(
            currentVersion: "0.0.3",
            channel: .appStore,
            manifest: manifest
        )
        XCTAssertEqual(
            appStore,
            .available(version: "0.0.4", url: URL(string: "https://apps.apple.com/app/id123")!)
        )

        XCTAssertEqual(
            AppUpdate.evaluate(currentVersion: "0.0.4", channel: .testFlight, manifest: manifest),
            .upToDate
        )
    }

    func testMissingAppStoreURLDoesNotOpenTestFlight() {
        let unpublished = AppVersionManifest(
            version: "0.0.4",
            build: 4,
            testflightUrl: manifest.testflightUrl,
            appStoreUrl: ""
        )
        XCTAssertEqual(
            AppUpdate.evaluate(currentVersion: "0.0.3", channel: .appStore, manifest: unpublished),
            .storeLinkMissing(version: "0.0.4")
        )
        XCTAssertEqual(
            AppUpdate.evaluate(currentVersion: "0.0.3", channel: .testFlight, manifest: unpublished),
            .available(version: "0.0.4", url: URL(string: manifest.testflightUrl)!)
        )
    }

    func testDualChannelUsesAppStoreVersionSeparatelyFromTestFlight() throws {
        let dualChannel = AppVersionManifest(
            version: "1.0.1",
            build: 10001,
            testflightUrl: manifest.testflightUrl,
            appStoreUrl: "https://apps.apple.com/app/id123",
            appStoreVersion: "1.0.0"
        )
        XCTAssertEqual(
            AppUpdate.evaluate(currentVersion: "1.0.0", channel: .appStore, manifest: dualChannel),
            .upToDate
        )
        XCTAssertEqual(
            AppUpdate.evaluate(currentVersion: "1.0.0", channel: .testFlight, manifest: dualChannel),
            .available(version: "1.0.1", url: URL(string: manifest.testflightUrl)!)
        )

        let preLaunchAppStore = AppVersionManifest(
            version: "0.0.11",
            build: 11,
            testflightUrl: manifest.testflightUrl,
            appStoreUrl: "",
            appStoreVersion: ""
        )
        XCTAssertEqual(
            AppUpdate.evaluate(currentVersion: "0.0.9", channel: .appStore, manifest: preLaunchAppStore),
            .upToDate
        )

        let legacyJSON = Data("""
        {
          "version": "0.0.9",
          "build": 9,
          "testflightUrl": "https://testflight.apple.com/join/YumojiTest",
          "appStoreUrl": ""
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(AppVersionManifest.self, from: legacyJSON)
        XCTAssertNil(decoded.appStoreVersion)
        XCTAssertEqual(decoded.version, "0.0.9")
    }

    func testCheckerParsesManifestViaMockSession() async {
        let endpoint = URL(string: "https://mock.flightdeck.invalid/v1/apps/yumoji/version.json")!
        let checker = AppUpdateChecker(endpoint: endpoint, session: makeMockSession())

        MockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url, endpoint)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let body = Data("""
            {
              "version": "0.2.0",
              "build": 20,
              "testflightUrl": "https://testflight.apple.com/join/YumojiTest",
              "appStoreUrl": "https://apps.apple.com/app/id123",
              "appStoreVersion": "0.1.5"
            }
            """.utf8)
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }

        let available = await checker.check(currentVersion: "0.1.0", channel: .testFlight)
        XCTAssertEqual(
            available,
            .available(version: "0.2.0", url: URL(string: "https://testflight.apple.com/join/YumojiTest")!)
        )

        let upToDate = await checker.check(currentVersion: "0.1.5", channel: .appStore)
        XCTAssertEqual(upToDate, .upToDate)
    }

    func testCheckerReturnsFailedOnNon2xxInvalidJSONAndNetworkError() async {
        let endpoint = URL(string: "https://mock.flightdeck.invalid/v1/apps/yumoji/version.json")!
        let checker = AppUpdateChecker(endpoint: endpoint, session: makeMockSession())

        MockURLProtocol.setHandler { _ in
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let httpFail = await checker.check(currentVersion: "0.1.0", channel: .testFlight)
        XCTAssertEqual(httpFail, .failed)

        MockURLProtocol.setHandler { _ in
            let response = HTTPURLResponse(
                url: endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("not json".utf8))
        }
        let decodeFail = await checker.check(currentVersion: "0.1.0", channel: .testFlight)
        XCTAssertEqual(decodeFail, .failed)

        MockURLProtocol.setHandler { _ in
            throw URLError(.notConnectedToInternet)
        }
        let networkFail = await checker.check(currentVersion: "0.1.0", channel: .testFlight)
        XCTAssertEqual(networkFail, .failed)
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

private final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    private static var handler: Handler?

    static func setHandler(_ newHandler: @escaping Handler) {
        lock.lock()
        handler = newHandler
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let currentHandler = Self.handler
        Self.lock.unlock()

        guard let currentHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try currentHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
