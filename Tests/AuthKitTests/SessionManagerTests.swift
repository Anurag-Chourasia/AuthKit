//
//  SessionManagerTests.swift
//  AuthKit
//
//  Created by Anurag Chourasia on 31/10/26.
//

import XCTest
@testable import AuthKit

final class SessionManagerTests: XCTestCase {

    @MainActor
    func testInitialStateIsLoading() {
        let backend = MockAuthBackend()
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        XCTAssertEqual(sut.state, .loading)
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testRestoreSessionWithoutUser() async {
        let backend = MockAuthBackend()
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        await sut.restoreSession()

        XCTAssertEqual(sut.state, .unauthenticated)
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testSuccessfulLogin() async {
        let backend = MockAuthBackend()
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        await sut.signIn(
            email: "test@example.com",
            password: "Password123"
        )

        guard case .authenticated(let user) = sut.state else {
            XCTFail("Expected authenticated state")
            return
        }

        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testSignOut() async {
        let backend = MockAuthBackend()
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        await sut.signIn(
            email: "test@example.com",
            password: "Password123"
        )

        await sut.signOut()

        XCTAssertEqual(sut.state, .unauthenticated)
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testSignInFailure() async {
        // Given
        let backend = MockAuthBackend(shouldFail: true)
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        // When
        await sut.signIn(
            email: "test@example.com",
            password: "wrong"
        )

        // Then
        XCTAssertEqual(sut.state, .unauthenticated)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testRestoreSessionFailure() async {
        // Given
        let backend = MockAuthBackend(
            failOnCurrentUser: true
        )
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        // When
        await sut.restoreSession()

        // Then
        XCTAssertEqual(sut.state, .unauthenticated)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testSignOutFailure() async {
        // Given
        let backend = MockAuthBackend(
            failOnSignOut: true
        )
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        await sut.signIn(
            email: "test@example.com",
            password: "Password123"
        )

        // When
        await sut.signOut()

        // Then
        guard case .authenticated(let user) = sut.state else {
            XCTFail("Session must remain authenticated")
            return
        }

        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testDeleteAccountSuccess() async {
        let backend = MockAuthBackend()
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        await sut.signIn(
            email: "delete-me@example.com",
            password: "Password123"
        )
        guard case .authenticated = sut.state else {
            XCTFail("Must be authenticated before deletion")
            return
        }

        await sut.deleteAccount()

        XCTAssertEqual(sut.state, .unauthenticated)
        XCTAssertEqual(sut.semanticNotice, .accountDeleted)
        XCTAssertEqual(sut.notice, AuthNotice.accountDeleted.localizationKey)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testDeleteAccountFailureIsRecoverable() async {
        let backend = MockAuthBackend(shouldFail: true)
        let service = AuthService(backend: backend)
        let sut = SessionManager(authService: service)

        // Attempt deletion when backend fails
        await sut.deleteAccount()

        XCTAssertEqual(sut.semanticError, .accountDeletionFailed)
        XCTAssertEqual(sut.errorMessage, AuthSessionError.accountDeletionFailed.localizationKey)
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func testSemanticNoticesAndUntrustedProviderErrorFallback() async throws {
        let sut = SessionManager(authService: AuthService(backend: MockAuthBackend()))
        let callback = try XCTUnwrap(URL(string: "test-auth://callback"))

        await sut.signUp(email: "test@example.com", password: "Password123")
        XCTAssertEqual(sut.semanticNotice, .confirmEmail)
        XCTAssertEqual(sut.notice, "auth.notice.confirm_email")

        await sut.requestPasswordReset(email: "test@example.com", redirectTo: callback)
        XCTAssertEqual(sut.semanticNotice, .passwordResetSent)
        XCTAssertEqual(sut.notice, "auth.notice.password_reset_sent")

        await sut.updatePassword("NewPassword123")
        XCTAssertEqual(sut.semanticNotice, .passwordUpdated)
        XCTAssertEqual(sut.notice, "auth.notice.password_updated")

        let failing = SessionManager(authService: AuthService(backend: MockAuthBackend(shouldFail: true)))
        await failing.signIn(email: "test@example.com", password: "wrong")
        XCTAssertEqual(failing.semanticError, .invalidCredentials)
        XCTAssertEqual(failing.errorMessage, "errors.invalid_credentials")
    }

    @MainActor
    func testAccountPresentationToggles() {
        let sut = SessionManager(authService: AuthService(backend: MockAuthBackend()))
        XCTAssertFalse(sut.isAccountPresented)
        sut.showAccount()
        XCTAssertTrue(sut.isAccountPresented)
        sut.hideAccount()
        XCTAssertFalse(sut.isAccountPresented)
    }

    @MainActor
    func testNetworkErrorSemanticMapping() async {
        let failing = SessionManager(authService: AuthService(backend: NetworkFailingBackend()))
        await failing.signIn(email: "a@b.com", password: "pwd")
        XCTAssertEqual(sutSemanticError(failing), .networkUnreachable)
    }

    @MainActor
    private func sutSemanticError(_ sut: SessionManager) -> AuthSessionError? {
        sut.semanticError
    }
}

private actor NetworkFailingBackend: AuthBackend {
    func currentUser() async throws -> AuthUser? { throw URLError(.notConnectedToInternet) }
    func events() async -> AsyncStream<AuthSessionEvent> { AsyncStream { $0.finish() } }
    func signIn(email: String, password: String) async throws -> AuthUser { throw URLError(.networkConnectionLost) }
    func signUp(email: String, password: String) async throws -> Bool { throw URLError(.notConnectedToInternet) }
    func signOut() async throws { throw URLError(.notConnectedToInternet) }
    func refreshSession() async throws { throw URLError(.notConnectedToInternet) }
    func requestPasswordReset(email: String, redirectTo: URL) async throws { throw URLError(.notConnectedToInternet) }
    func updatePassword(_ password: String) async throws { throw URLError(.notConnectedToInternet) }
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser { throw URLError(.notConnectedToInternet) }
    func handleCallback(_ url: URL) async throws -> AuthUser { throw URLError(.notConnectedToInternet) }
    func deleteAccount() async throws { throw URLError(.notConnectedToInternet) }
}
