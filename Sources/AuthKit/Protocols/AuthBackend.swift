import Foundation

public protocol AuthBackend: Sendable {
    func signIn(email: String, password: String) async throws -> AuthUser
    func signUp(email: String, password: String) async throws -> Bool
    func currentUser() async throws -> AuthUser?
    func refreshSession() async throws
    func events() async -> AsyncStream<AuthSessionEvent>
    func requestPasswordReset(email: String, redirectTo: URL) async throws
    func updatePassword(_ password: String) async throws
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser
    func handleCallback(_ url: URL) async throws -> AuthUser
    func signOut() async throws
    func deleteAccount() async throws
    func updateProfile(email: String?, firstName: String?, lastName: String?, phone: String?) async throws -> AuthUser
    func updateProfile(firstName: String?, lastName: String?, phone: String?) async throws -> AuthUser
    func sendPasswordResetOTP(email: String?, phone: String?) async throws
    func verifyPasswordResetOTP(email: String?, phone: String?, token: String) async throws
    func changePassword(currentPassword: String, newPassword: String, otpCode: String) async throws
}

public extension AuthBackend {
    func updateProfile(firstName: String?, lastName: String?, phone: String?) async throws -> AuthUser {
        try await updateProfile(email: nil, firstName: firstName, lastName: lastName, phone: phone)
    }

    func updateProfile(email: String?, firstName: String?, lastName: String?, phone: String?) async throws -> AuthUser {
        guard let current = try await currentUser() else {
            throw NSError(domain: "AuthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active user"])
        }
        return AuthUser(
            id: current.id, email: email ?? current.email,
            firstName: firstName ?? current.firstName,
            lastName: lastName ?? current.lastName, phone: phone ?? current.phone
        )
    }

    func sendPasswordResetOTP(email: String?, phone: String?) async throws {}

    func verifyPasswordResetOTP(email: String?, phone: String?, token: String) async throws {}

    func changePassword(currentPassword: String, newPassword: String, otpCode: String) async throws {
        try await updatePassword(newPassword)
    }
}
