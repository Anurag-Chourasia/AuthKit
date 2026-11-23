import Foundation
import AuthKit
import Supabase

public actor SupabaseAuthBackend: AuthBackend {
    let client: SupabaseClient

    public init(manager: SupabaseManager) { self.client = manager.client }
    public init(client: SupabaseClient) { self.client = client }

    public func signIn(email: String, password: String) async throws -> AuthUser {
        let session = try await client.auth.signIn(email: email, password: password)
        return Self.makeAuthUser(from: session.user)
    }

    public func signUp(email: String, password: String) async throws -> Bool {
        let response = try await client.auth.signUp(email: email, password: password)
        return response.session == nil
    }

    public func currentUser() async throws -> AuthUser? {
        do {
            let session = try await client.auth.session
            return Self.makeAuthUser(from: session.user)
        } catch AuthError.sessionMissing {
            return nil
        }
    }

    public func refreshSession() async throws {
        _ = try await client.auth.refreshSession()
    }

    public func signOut() async throws {
        try await client.auth.signOut(scope: .local)
    }

    public func deleteAccount() async throws {
        try await client.functions.invoke("delete-user-account")
        try await client.auth.signOut(scope: .local)
    }

    public func events() async -> AsyncStream<AuthSessionEvent> {
        let changes = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await change in changes {
                    guard !Task.isCancelled else { break }
                    continuation.yield(AuthSessionEvent(
                        user: change.session.map { Self.makeAuthUser(from: $0.user) },
                        isPasswordRecovery: change.event == .passwordRecovery))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func requestPasswordReset(email: String, redirectTo: URL) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: redirectTo)
    }

    public func updatePassword(_ password: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: password))
    }

    public func updateProfile(
        email: String? = nil, firstName: String?, lastName: String?, phone: String?
    ) async throws -> AuthUser {
        var data: [String: AnyJSON] = [:]
        if let firstName { data["first_name"] = .string(firstName) }
        if let lastName { data["last_name"] = .string(lastName) }
        if let firstName, let lastName { data["full_name"] = .string("\(firstName) \(lastName)") }
        let cleanPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneToUpdate = (cleanPhone?.isEmpty == false) ? cleanPhone : nil
        if let phoneToUpdate {
            data["phone"] = .string(phoneToUpdate)
            data["phone_number"] = .string(phoneToUpdate)
        } else if phone != nil {
            data["phone"] = .null
            data["phone_number"] = .null
        }
        let cleanEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailToUpdate = (cleanEmail?.isEmpty == false) ? cleanEmail : nil
        var returnedUser: AuthUser
        do {
            let attrs = UserAttributes(email: emailToUpdate, phone: phoneToUpdate, data: data.isEmpty ? nil : data)
            let updatedUser = try await client.auth.update(user: attrs)
            returnedUser = Self.makeAuthUser(from: updatedUser)
        } catch {
            let fallback = UserAttributes(email: emailToUpdate, data: data.isEmpty ? nil : data)
            let updatedUser = try await client.auth.update(user: fallback)
            returnedUser = Self.makeAuthUser(from: updatedUser)
        }
        if (returnedUser.phone == nil || returnedUser.phone?.isEmpty == true), let phoneToUpdate {
            returnedUser = AuthUser(
                id: returnedUser.id, email: returnedUser.email, firstName: returnedUser.firstName,
                lastName: returnedUser.lastName, phone: phoneToUpdate
            )
        }
        return returnedUser
    }

    public func updateProfile(firstName: String?, lastName: String?, phone: String?) async throws -> AuthUser {
        try await updateProfile(email: nil, firstName: firstName, lastName: lastName, phone: phone)
    }

    public func handleCallback(_ url: URL) async throws -> AuthUser {
        let session = try await client.auth.session(from: url)
        return Self.makeAuthUser(from: session.user)
    }

    public func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser {
        let sdkProvider: Provider
        switch provider {
        case .google: sdkProvider = .google
        case .github: sdkProvider = .github
        case .apple: sdkProvider = .apple
        }
        let session = try await client.auth.signInWithOAuth(provider: sdkProvider, redirectTo: redirectTo)
        return Self.makeAuthUser(from: session.user)
    }

    private static func makeAuthUser(from user: User) -> AuthUser {
        var firstName: String?
        var lastName: String?
        let meta = user.userMetadata
        if case .string(let first) = meta["first_name"] { firstName = first }
        if case .string(let last) = meta["last_name"] { lastName = last }
        if firstName == nil && lastName == nil {
            if case .string(let full) = meta["full_name"] ?? meta["name"] {
                let parts = full.split(separator: " ", maxSplits: 1).map(String.init)
                firstName = parts.first; if parts.count > 1 { lastName = parts.last }
            }
        }
        var phone = user.phone
        if phone == nil || phone?.isEmpty == true,
           case .string(let metaPhone) = meta["phone"] ?? meta["phone_number"] {
            phone = metaPhone
        }
        return AuthUser(id: user.id, email: user.email, firstName: firstName, lastName: lastName, phone: phone)
    }
}
