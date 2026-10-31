import XCTest
@testable import AuthKit

final class AuthServiceTests: XCTestCase {

    func testSignInSuccess() async throws {
        // Given
        let backend = MockAuthBackend()
        let sut = AuthService(backend: backend)

        // When
        let user = try await sut.signIn(
            email: "test@example.com",
            password: "Password123"
        )

        // Then
        XCTAssertEqual(user.email, "test@example.com")
    }

    func testSignInFailure() async {
        // Given
        let backend = MockAuthBackend(
            shouldFail: true
        )
        let sut = AuthService(backend: backend)

        // When / Then
        do {
            _ = try await sut.signIn(
                email: "test@example.com",
                password: "wrong"
            )

            XCTFail("Expected login to fail")
        } catch MockAuthError.invalidCredentials {
            return // PASS: Correct error received
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSignOut() async throws {
        // Given
        let backend = MockAuthBackend()
        let sut = AuthService(backend: backend)

        _ = try await sut.signIn(
            email: "test@example.com",
            password: "Password123"
        )

        // When
        try await sut.signOut()

        // Then
        let user = try await sut.currentUser()
        XCTAssertNil(user)
    }

    func testSignUp() async throws {
        let backend = MockAuthBackend()
        let sut = AuthService(backend: backend)

        let requiresConfirmation = try await sut.signUp(
            email: "test@example.com",
            password: "Password123"
        )

        XCTAssertTrue(requiresConfirmation)
    }

    func testCurrentUserWithoutSession() async throws {
        let backend = MockAuthBackend()
        let sut = AuthService(backend: backend)

        let user = try await sut.currentUser()

        XCTAssertNil(user)
    }

    func testRefreshSessionSuccess() async throws {
        let backend = MockAuthBackend()
        let sut = AuthService(backend: backend)

        try await sut.refreshSession()
    }

    func testRefreshSessionFailure() async {
        let backend = MockAuthBackend(shouldFail: true)
        let sut = AuthService(backend: backend)

        do {
            try await sut.refreshSession()
            XCTFail("Expected refresh to fail")
        } catch MockAuthError.invalidCredentials {
            return // PASS: Correct error received
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }


    func testSignUpFailure() async {
        // Given
        let backend = MockAuthBackend(shouldFail: true)
        let sut = AuthService(backend: backend)

        // When / Then
        do {
            _ = try await sut.signUp(
                email: "test@example.com",
                password: "Password123"
            )

            XCTFail("Expected signup to fail")
        } catch MockAuthError.invalidCredentials {
            // PASS: Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCurrentUserFailure() async {
        // Given
        let backend = MockAuthBackend(
            failOnCurrentUser: true
        )
        let sut = AuthService(backend: backend)

        // When / Then
        do {
            _ = try await sut.currentUser()

            XCTFail("Expected currentUser to fail")
        } catch MockAuthError.invalidCredentials {
            // PASS: Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSignOutFailure() async throws {
        // Given
        let backend = MockAuthBackend(
            failOnSignOut: true
        )
        let sut = AuthService(backend: backend)

        let signedInUser = try await sut.signIn(
            email: "test@example.com",
            password: "Password123"
        )

        // When / Then
        do {
            try await sut.signOut()

            XCTFail("Expected logout to fail")
        } catch MockAuthError.invalidCredentials {
            // PASS: Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify failed logout preserves the session
        let currentUser = try await sut.currentUser()

        XCTAssertEqual(currentUser, signedInUser)
    }

}
