import Foundation
import XCTest
import AuthKit
import AuthKitUI

final class AuthConfigurationTests: XCTestCase {
    func testReadinessPolicyFailsClosedAndPropagatesErrors() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.invalid"))
        let callback = try XCTUnwrap(URL(string: "test-auth://auth/callback"))
        let candidate = AppAuthConfiguration(projectURL: url, publishableKey: "public-test-key",
            callbackURL: callback, storageKey: "test.session")
        let unavailable = ReadinessCheckedAuthConfiguration(configuration: candidate, isReady: { false })
        let available = ReadinessCheckedAuthConfiguration(configuration: candidate, isReady: { true })
        let missing = ReadinessCheckedAuthConfiguration(configuration: nil, isReady: {
            XCTFail("Missing configuration must not invoke readiness")
            return true
        })
        let denied = try await unavailable.configuration()
        let resolved = try await available.configuration()
        let absent = try await missing.configuration()
        XCTAssertNil(denied)
        XCTAssertEqual(resolved?.storageKey, "test.session")
        XCTAssertNil(absent)
        let failed = ReadinessCheckedAuthConfiguration(configuration: candidate, isReady: { throw URLError(.notConnectedToInternet) })
        do { _ = try await failed.configuration(); XCTFail("Expected readiness error") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
    }

    func testOnlyExpectedCallbackEndpointIsAccepted() throws {
        let expected = try XCTUnwrap(URL(string: "test-auth://auth/callback"))
        let config = AppAuthConfiguration(projectURL: URL(string: "https://example.supabase.co")!,
            publishableKey: "fixture", callbackURL: expected, storageKey: "fixture")
        XCTAssertTrue(config.accepts(URL(string: "test-auth://auth/callback?code=fixture")!))
        XCTAssertFalse(config.accepts(URL(string: "other://auth/callback?code=fixture")!))
        XCTAssertFalse(config.accepts(URL(string: "test-auth://other/callback")!))
        XCTAssertFalse(config.accepts(URL(string: "test-auth://auth/not-callback")!))
    }

    func testEnvironmentIsolationAndStorageKeySuffix() throws {
        let callback = try XCTUnwrap(URL(string: "test-auth://auth/callback"))
        let prodConfig = AppAuthConfiguration(
            projectURL: URL(string: "https://example.supabase.co")!,
            publishableKey: "fixture-prod",
            callbackURL: callback,
            storageKey: "com.example.app.supabase.session",
            environment: .production
        )
        XCTAssertEqual(prodConfig.environment, .production)
        XCTAssertEqual(prodConfig.storageKey, "com.example.app.supabase.session")

        let stagingConfig = AppAuthConfiguration(
            projectURL: URL(string: "https://staging.supabase.co")!,
            publishableKey: "fixture-staging",
            callbackURL: callback,
            storageKey: "com.example.app.supabase.staging.session",
            environment: .staging
        )
        XCTAssertEqual(stagingConfig.environment, .staging)
        XCTAssertEqual(stagingConfig.storageKey, "com.example.app.supabase.staging.session")
        XCTAssertNotEqual(prodConfig.storageKey, stagingConfig.storageKey, "Staging and production storage keys must never collide")
    }
}
