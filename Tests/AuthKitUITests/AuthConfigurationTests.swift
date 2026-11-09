import Foundation
import SwiftUI
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
        do { _ = try await failed.configuration(); XCTFail("Expected readiness error") } catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
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

    @MainActor
    func testAppAuthGateAcceptsInjectableBackendFactory() throws {
        let callback = try XCTUnwrap(URL(string: "test-auth://auth/callback"))
        let config = AppAuthConfiguration(
            projectURL: URL(string: "https://example.supabase.co")!,
            publishableKey: "fixture",
            callbackURL: callback,
            storageKey: "fixture"
        )
        let gate = AppAuthGate(brand: .showBook, configuration: config, backendFactory: { _ in
            FakeAuthBackend()
        }) { user, _ in
            Text(user.id.uuidString)
        }
        XCTAssertNotNil(gate)
    }

    func testDefaultAuthLocalizerIntegratesLocalizationKit() {
        let localizer = DefaultAuthLocalizer()
        // Resolves via LocalizationKit
        XCTAssertEqual(localizer.string("auth.title.sign_in"), "Sign in")
        XCTAssertEqual(localizer.string("auth.field.email"), "Email")
        XCTAssertEqual(localizer.string("auth.field.password"), "Password")
        XCTAssertEqual(localizer.string("account.title"), "Account")
        XCTAssertEqual(localizer.string("common.cancel"), "Cancel")

        // KeyPath helper
        XCTAssertEqual(localizer.string(\.authTitleSignIn), "Sign in")
        XCTAssertEqual(localizer.string(\.authFieldEmail), "Email")

        // Custom string override
        let customLocalizer = DefaultAuthLocalizer(
            isRightToLeft: true,
            customStrings: ["auth.title.sign_in": "تسجيل الدخول"]
        )
        XCTAssertTrue(customLocalizer.isRightToLeft)
        XCTAssertEqual(customLocalizer.string("auth.title.sign_in"), "تسجيل الدخول")
        XCTAssertEqual(customLocalizer.string("auth.field.email"), "Email")
    }

    func testFromBundleResolutionAndFallback() throws {
        let bundleURL = FileManager.default.temporaryDirectory.appendingPathComponent("MockApp_\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        let plistData = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.example.mockapp</string>
            <key>SUPABASE_URL</key>
            <string>https://example.supabase.co</string>
            <key>SUPABASE_PUBLISHABLE_KEY</key>
            <string>mock-pub-key</string>
            <key>AUTH_CALLBACK_URL</key>
            <string>mockapp://auth/callback</string>
            <key>AUTH_PROVIDERS</key>
            <string>google, github, apple</string>
            <key>SUPABASE_STAGING_URL</key>
            <string>https://staging.supabase.co</string>
            <key>SUPABASE_STAGING_PUBLISHABLE_KEY</key>
            <string>mock-staging-key</string>
        </dict>
        </plist>
        """.utf8)

        let plistURL = bundleURL.appendingPathComponent("Info.plist")
        try plistData.write(to: plistURL)

        guard let bundle = Bundle(url: bundleURL) else {
            XCTFail("Failed to load bundle at \(bundleURL)")
            return
        }

        let prodConfig = AppAuthConfiguration.fromBundle(bundle, environment: .production)
        XCTAssertNotNil(prodConfig)
        XCTAssertEqual(prodConfig?.projectURL.absoluteString, "https://example.supabase.co")
        XCTAssertEqual(prodConfig?.publishableKey, "mock-pub-key")
        XCTAssertEqual(prodConfig?.storageKey, "com.example.mockapp.supabase.session")
        XCTAssertEqual(prodConfig?.providers, [.google, .github, .apple])

        let stagingConfig = AppAuthConfiguration.fromBundle(bundle, environment: .staging)
        XCTAssertNotNil(stagingConfig)
        XCTAssertEqual(stagingConfig?.projectURL.absoluteString, "https://staging.supabase.co")
        XCTAssertEqual(stagingConfig?.publishableKey, "mock-staging-key")
        XCTAssertEqual(stagingConfig?.storageKey, "com.example.mockapp.supabase.staging.session")

        // Incomplete bundle returns nil
        let emptyBundleURL = FileManager.default.temporaryDirectory.appendingPathComponent("Empty_\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: emptyBundleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyBundleURL) }
        let emptyBundle = Bundle(url: emptyBundleURL)
        XCTAssertNil(emptyBundle.flatMap { AppAuthConfiguration.fromBundle($0) })
    }

    func testAuthProvidersAndEnvironment() {
        XCTAssertEqual(AuthProvider.google.displayName, "Google")
        XCTAssertEqual(AuthProvider.github.displayName, "GitHub")
        XCTAssertEqual(AuthProvider.apple.displayName, "Apple")
        XCTAssertEqual(AuthEnvironment.allCases.count, 2)

        let event = AuthSessionEvent(user: nil, isPasswordRecovery: true)
        XCTAssertTrue(event.isPasswordRecovery)
    }
}

private actor FakeAuthBackend: AuthBackend {
    func currentUser() async throws -> AuthUser? { nil }
    func events() async -> AsyncStream<AuthSessionEvent> { AsyncStream { $0.finish() } }
    func signIn(email: String, password: String) async throws -> AuthUser { AuthUser(id: UUID(), email: email) }
    func signUp(email: String, password: String) async throws -> Bool { true }
    func signOut() async throws { }
    func refreshSession() async throws { }
    func requestPasswordReset(email: String, redirectTo: URL) async throws { }
    func updatePassword(_ password: String) async throws { }
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser { AuthUser(id: UUID(), email: nil) }
    func handleCallback(_ url: URL) async throws -> AuthUser { AuthUser(id: UUID(), email: nil) }
    func deleteAccount() async throws { }
}
