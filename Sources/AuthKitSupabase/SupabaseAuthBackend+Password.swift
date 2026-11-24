import Foundation
import AuthKit
import Supabase

extension SupabaseAuthBackend {

    public func sendPasswordResetOTP(email: String?, phone: String?) async throws {
        if let email, !email.isEmpty {
            try await client.auth.resetPasswordForEmail(email)
        } else if let phone, !phone.isEmpty {
            try await client.auth.signInWithOTP(phone: phone, shouldCreateUser: false)
        }
    }

    public func verifyPasswordResetOTP(email: String?, phone: String?, token: String) async throws {
        if let email, !email.isEmpty {
            do {
                _ = try await client.auth.verifyOTP(email: email, token: token, type: .email)
            } catch {
                _ = try await client.auth.verifyOTP(email: email, token: token, type: .recovery)
            }
        } else if let phone, !phone.isEmpty {
            _ = try await client.auth.verifyOTP(phone: phone, token: token, type: .sms)
        }
    }

    public func changePassword(currentPassword: String, newPassword: String, otpCode: String) async throws {
        let user = try await currentUser()
        if let email = user?.email, !email.isEmpty {
            _ = try await client.auth.signIn(email: email, password: currentPassword)
        }
        if !otpCode.isEmpty {
            try await verifyPasswordResetOTP(email: user?.email, phone: user?.phone, token: otpCode)
        }
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    public func changePassword(currentPassword: String, newPassword: String) async throws {
        let user = try await currentUser()
        if let email = user?.email, !email.isEmpty {
            _ = try await client.auth.signIn(email: email, password: currentPassword)
        }
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }
}
