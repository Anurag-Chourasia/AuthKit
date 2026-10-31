import Foundation
import XCTest
@testable import AuthKit

private actor ControlledBackend: AuthBackend {
    let stream: AsyncStream<AuthSessionEvent>
    let continuation: AsyncStream<AuthSessionEvent>.Continuation
    var pending: CheckedContinuation<AuthUser, any Error>?
    var calls = 0
    var listening = false
    init() {
        let pair = AsyncStream<AuthSessionEvent>.makeStream()
        stream = pair.stream; continuation = pair.continuation
    }
    func events() async -> AsyncStream<AuthSessionEvent> { listening = true; return stream }
    func emit(_ event: AuthSessionEvent) { continuation.yield(event) }
    func signIn(email: String, password: String) async throws -> AuthUser {
        calls += 1
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func complete(_ user: AuthUser) { pending?.resume(returning: user); pending = nil }
    func currentUser() async throws -> AuthUser? { nil }
    func signUp(email: String, password: String) async throws -> Bool { true }
    func signOut() async throws { calls += 1 }
    func refreshSession() async throws { }
    func requestPasswordReset(email: String, redirectTo: URL) async throws { }
    func updatePassword(_ password: String) async throws { }
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser {
        AuthUser(id: UUID(), email: nil)
    }
    func handleCallback(_ url: URL) async throws -> AuthUser { AuthUser(id: UUID(), email: nil) }
}

@MainActor
final class SessionEventsTests: XCTestCase {
    private func wait(_ condition: () async -> Bool) async throws {
        for _ in 0..<1000 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for state")
    }

    func testEventsDriveRecoveryAndSignOut() async throws {
        let backend = ControlledBackend()
        let sut = SessionManager(authService: AuthService(backend: backend))
        let observation = Task { await sut.observeAuthChanges() }
        defer { observation.cancel() }
        try await wait { await backend.listening }
        let user = AuthUser(id: UUID(), email: "test@example.com")
        await backend.emit(.init(user: user, isPasswordRecovery: true))
        try await wait { sut.isPasswordRecovery }
        XCTAssertEqual(sut.state, .authenticated(user))
        await backend.emit(.init(user: nil))
        try await wait { sut.state == .unauthenticated }
        XCTAssertFalse(sut.isPasswordRecovery)
    }

    func testBusyOperationRejectsOverlapAndLateResultCannotUndoSignOutEvent() async throws {
        let backend = ControlledBackend()
        let sut = SessionManager(authService: AuthService(backend: backend))
        let observation = Task { await sut.observeAuthChanges() }
        defer { observation.cancel() }
        try await wait { await backend.listening }
        let login = Task { await sut.signIn(email: "first@example.com", password: "secret") }
        try await wait { await backend.calls == 1 }
        await sut.signOut()
        let calls = await backend.calls
        XCTAssertEqual(calls, 1)
        await backend.emit(.init(user: nil))
        try await wait { sut.state == .unauthenticated }
        await backend.complete(.init(id: UUID(), email: "first@example.com"))
        await login.value
        XCTAssertEqual(sut.state, .unauthenticated)
        XCTAssertFalse(sut.isLoading)
    }

    func testSignUpRecoveryAndProviderOperations() async throws {
        let sut = SessionManager(authService: AuthService(backend: MockAuthBackend()))
        let callback = try XCTUnwrap(URL(string: "test-auth://callback"))
        await sut.signUp(email: "test@example.com", password: "test-password")
        XCTAssertNotNil(sut.notice)
        await sut.requestPasswordReset(email: "test@example.com", redirectTo: callback)
        XCTAssertNotNil(sut.notice)
        await sut.updatePassword("changed-password")
        XCTAssertNotNil(sut.notice)
        for provider in AuthProvider.allCases {
            await sut.signIn(provider: provider, redirectTo: callback)
            guard case .authenticated = sut.state else { return XCTFail("Provider did not sign in") }
        }
        await sut.handleCallback(callback)
        guard case .authenticated = sut.state else { return XCTFail("Callback did not sign in") }
    }
}
