import Foundation
import XCTest
import Supabase
@testable import AuthKit

final class SessionStorageTests: XCTestCase {
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
