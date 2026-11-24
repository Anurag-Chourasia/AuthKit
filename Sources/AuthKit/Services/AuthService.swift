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
    public func requestPasswordReset(email: String) async throws {
        try await backend.requestPasswordReset(email: email)
    }
    public func updatePassword(_ password: String) async throws { try await backend.updatePassword(password) }
    public func sendPasswordResetOTP(email: String?, phone: String?) async throws {
        try await backend.sendPasswordResetOTP(email: email, phone: phone)
    }
    public func verifyPasswordResetOTP(email: String?, phone: String?, token: String) async throws {
        try await backend.verifyPasswordResetOTP(email: email, phone: phone, token: token)
    }
    public func changePassword(currentPassword: String, newPassword: String, otpCode: String) async throws {
        try await backend.changePassword(
            currentPassword: currentPassword, newPassword: newPassword, otpCode: otpCode
        )
    }
    public func changePassword(currentPassword: String, newPassword: String) async throws {
        try await backend.changePassword(
            currentPassword: currentPassword, newPassword: newPassword
        )
    }
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

    // MARK: - Update Profile

    public func updateProfile(
        email: String? = nil,
        firstName: String?,
        lastName: String?,
        phone: String?
    ) async throws -> AuthUser {
        try await backend.updateProfile(
            email: email,
            firstName: firstName,
            lastName: lastName,
            phone: phone
        )
    }

    public func updateProfile(
        firstName: String?,
        lastName: String?,
        phone: String?
    ) async throws -> AuthUser {
        try await backend.updateProfile(
            email: nil,
            firstName: firstName,
            lastName: lastName,
            phone: phone
        )
    }
}
