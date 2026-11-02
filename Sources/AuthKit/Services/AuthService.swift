import Foundation

public final class AuthService: Sendable {

    private let backend: any AuthBackend

    public init(backend: any AuthBackend) {
        self.backend = backend
    }

    public func events() async -> AsyncStream<AuthSessionEvent> { await backend.events() }
    public func requestPasswordReset(email: String, redirectTo: URL) async throws {
        try await backend.requestPasswordReset(email: email, redirectTo: redirectTo)
    }
    public func updatePassword(_ password: String) async throws { try await backend.updatePassword(password) }
    public func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser {
        try await backend.signIn(provider: provider, redirectTo: redirectTo)
    }
    public func handleCallback(_ url: URL) async throws -> AuthUser { try await backend.handleCallback(url) }

    // MARK: - Sign In

    public func signIn(
        email: String,
        password: String
    ) async throws -> AuthUser {
        try await backend.signIn(
            email: email,
            password: password
        )
    }

    // MARK: - Sign Up

    public func signUp(
        email: String,
        password: String
    ) async throws -> Bool {
        try await backend.signUp(
            email: email,
            password: password
        )
    }

    // MARK: - Current User

    public func currentUser() async throws -> AuthUser? {
        try await backend.currentUser()
    }

    // MARK: - Refresh Session

    public func refreshSession() async throws {
        try await backend.refreshSession()
    }

    // MARK: - Sign Out

    public func signOut() async throws {
        try await backend.signOut()
    }

    // MARK: - Delete Account

    public func deleteAccount() async throws {
        try await backend.deleteAccount()
    }
}
