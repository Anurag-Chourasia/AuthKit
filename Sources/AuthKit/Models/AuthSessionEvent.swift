import Foundation

public enum AuthProvider: String, CaseIterable, Sendable {
    case google, github, apple
}

public struct AuthSessionEvent: Sendable {
    public let user: AuthUser?
    public let isPasswordRecovery: Bool
    public init(user: AuthUser?, isPasswordRecovery: Bool = false) {
        self.user = user
        self.isPasswordRecovery = isPasswordRecovery
    }
}
