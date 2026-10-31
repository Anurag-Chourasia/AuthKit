import Foundation
import XCTest
import AuthKitUI

final class AuthConfigurationTests: XCTestCase {
    func testOnlyExpectedCallbackEndpointIsAccepted() throws {
        let expected = try XCTUnwrap(URL(string: "test-auth://auth/callback"))
        let config = AppAuthConfiguration(projectURL: URL(string: "https://example.supabase.co")!,
            publishableKey: "fixture", callbackURL: expected, storageKey: "fixture")
        XCTAssertTrue(config.accepts(URL(string: "test-auth://auth/callback?code=fixture")!))
        XCTAssertFalse(config.accepts(URL(string: "other://auth/callback?code=fixture")!))
        XCTAssertFalse(config.accepts(URL(string: "test-auth://other/callback")!))
        XCTAssertFalse(config.accepts(URL(string: "test-auth://auth/not-callback")!))
    }
}
