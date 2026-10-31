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

}
