//
//  MockAuthBackend.swift
//  AuthKit
//
//  Created by Anurag Chourasia on 31/10/26.
//



import Foundation
@testable import AuthKit

enum MockAuthError: Error {
    case invalidCredentials
}

actor MockAuthBackend: AuthBackend {

    private let shouldFail: Bool
    private var signedInUser: AuthUser?

    private let failOnCurrentUser: Bool
    private let failOnSignOut: Bool

    init(
        shouldFail: Bool = false,
        failOnCurrentUser: Bool = false,
        failOnSignOut: Bool = false
    ) {
        self.shouldFail = shouldFail
        self.failOnCurrentUser = failOnCurrentUser
        self.failOnSignOut = failOnSignOut
    }

    // MARK: - Sign In

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthUser {

        if shouldFail {
            throw MockAuthError.invalidCredentials
        }

        let user = AuthUser(
            id: UUID(),
            email: email
        )

        signedInUser = user
        return user
    }

    // MARK: - Sign Up

    func signUp(
        email: String,
        password: String
    ) async throws -> Bool {

        if shouldFail {
            throw MockAuthError.invalidCredentials
        }

        return true
    }

    // MARK: - Current User

    func currentUser() async throws -> AuthUser? {
        if failOnCurrentUser {
            throw MockAuthError.invalidCredentials
        }

        return signedInUser
    }

    // MARK: - Refresh Session

    func refreshSession() async throws {
        if shouldFail {
            throw MockAuthError.invalidCredentials
        }
    }

    // MARK: - Sign Out

    func signOut() async throws {
        if failOnSignOut {
            throw MockAuthError.invalidCredentials
        }

        signedInUser = nil
    }
    func events() async -> AsyncStream<AuthSessionEvent> { AsyncStream { $0.finish() } }
    func requestPasswordReset(email: String, redirectTo: URL) async throws {
        if shouldFail { throw MockAuthError.invalidCredentials }
    }
    func updatePassword(_ password: String) async throws {
        if shouldFail { throw MockAuthError.invalidCredentials }
    }
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser {
        try await signIn(email: "provider@example.com", password: "")
    }
    func handleCallback(_ url: URL) async throws -> AuthUser {
        try await signIn(email: "callback@example.com", password: "")
    }

    func deleteAccount() async throws {
        if shouldFail {
            throw MockAuthError.invalidCredentials
        }
        signedInUser = nil
    }
}
