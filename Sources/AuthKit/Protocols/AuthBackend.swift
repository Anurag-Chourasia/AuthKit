//
//  AuthBackend.swift
//  AuthKit
//
//  Created by Anurag Chourasia on 31/10/26.
//

import Foundation

public protocol AuthBackend: Sendable {

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthUser

    func signUp(
        email: String,
        password: String
    ) async throws -> Bool

    func currentUser() async throws -> AuthUser?

    func refreshSession() async throws

    func events() async -> AsyncStream<AuthSessionEvent>
    func requestPasswordReset(email: String, redirectTo: URL) async throws
    func updatePassword(_ password: String) async throws
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser
    func handleCallback(_ url: URL) async throws -> AuthUser
    func signOut() async throws
    func deleteAccount() async throws
    func updateProfile(firstName: String?, lastName: String?, phone: String?) async throws -> AuthUser
}

extension AuthBackend {
    public func updateProfile(
        firstName: String?,
        lastName: String?,
        phone: String?
    ) async throws -> AuthUser {
        guard let current = try await currentUser() else {
            throw NSError(domain: "AuthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active user"])
        }
        return AuthUser(
            id: current.id,
            email: current.email,
            firstName: firstName ?? current.firstName,
            lastName: lastName ?? current.lastName,
            phone: phone ?? current.phone
        )
    }
}
