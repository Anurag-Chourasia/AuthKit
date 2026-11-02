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
}
