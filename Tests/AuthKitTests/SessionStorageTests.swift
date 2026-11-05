import AuthKitSupabase
import Foundation
import XCTest
import Supabase
@testable import AuthKit

final class SessionStorageTests: XCTestCase {
    func testKeychainRoundTripUpdateIsolationAndDeletion() throws {
        #if os(macOS)
        let storage = KeychainLocalStorage(service: "AuthKit.Tests." + UUID().uuidString)
        let first = "session-one"
        let second = "session-two"
        defer { try? storage.remove(key: first); try? storage.remove(key: second) }
        XCTAssertThrowsError(try storage.retrieve(key: first))
        try storage.store(key: first, value: Data("initial".utf8))
        try storage.store(key: second, value: Data("isolated".utf8))
        try storage.store(key: first, value: Data("updated".utf8))
        XCTAssertEqual(try storage.retrieve(key: first), Data("updated".utf8))
        XCTAssertEqual(try storage.retrieve(key: second), Data("isolated".utf8))
        try storage.remove(key: first)
        XCTAssertThrowsError(try storage.retrieve(key: first))
        XCTAssertEqual(try storage.retrieve(key: second), Data("isolated".utf8))
        #else
        throw XCTSkip("The unsigned iOS package runner has no Keychain entitlement. Real Keychain coverage runs on macOS; signed iOS host verification remains a release gate.")
        #endif
    }

    func testSessionRestoresThroughInjectedStorageAndRemainsIsolated() async throws {
        let storage = InMemoryAuthStorage()
        let now = Date()
        let user = User(id: UUID(), appMetadata: [:], userMetadata: [:], aud: "authenticated",
                        email: "fixture@example.com", createdAt: now, updatedAt: now)
        let session = Session(accessToken: "fixture", tokenType: "bearer", expiresIn: 3600,
                              expiresAt: now.timeIntervalSince1970 + 3600,
                              refreshToken: "fixture-refresh", user: user)
        try storage.store(key: "app-one", value: JSONEncoder().encode(session))
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let first = SupabaseManager(url: url, publishableKey: "fixture",
            authOptions: .init(storage: storage, storageKey: "app-one", autoRefreshToken: false))
        let second = SupabaseManager(url: url, publishableKey: "fixture",
            authOptions: .init(storage: storage, storageKey: "app-two", autoRefreshToken: false))
        let restored = try await SupabaseAuthBackend(manager: first).currentUser()
        let isolated = try await SupabaseAuthBackend(manager: second).currentUser()
        XCTAssertEqual(restored?.id, user.id)
        XCTAssertNil(isolated)
        try storage.remove(key: "app-one")
        let cleared = try await SupabaseAuthBackend(manager: first).currentUser()
        XCTAssertNil(cleared)
    }
}
