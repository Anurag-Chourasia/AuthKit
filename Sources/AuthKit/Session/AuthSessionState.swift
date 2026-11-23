import Foundation

public enum AuthState: Equatable, Sendable {
    case loading
    case authenticated(AuthUser)
    case unauthenticated
}

/// Semantic notice states emitted by `SessionManager`.
public enum AuthNotice: String, CaseIterable, Equatable, Sendable {
    case confirmEmail = "auth.notice.confirm_email"
    case accountDeleted = "auth.notice.account_deleted"
    case passwordResetSent = "auth.notice.password_reset_sent"
    case passwordUpdated = "auth.notice.password_updated"

    public var localizationKey: String { rawValue }
}

/// Semantic authentication failure categories emitted by `SessionManager`.
public enum AuthSessionError: String, CaseIterable, Equatable, Sendable {
    case networkUnreachable = "errors.network_unreachable"
    case invalidCredentials = "errors.invalid_credentials"
    case sessionExpired = "errors.session_expired"
    case accountDeletionFailed = "errors.account_deletion_failed"
    case generic = "errors.generic"

    public var localizationKey: String { rawValue }
}
