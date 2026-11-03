import Foundation

public enum AuthProvider: String, CaseIterable, Sendable {
    case google, github, apple
    public var displayName: String {
        switch self { case .google: "Google"; case .github: "GitHub"; case .apple: "Apple" }
    }
}

public enum AuthEnvironment: String, Sendable, CaseIterable {
    case production
    case staging
}

public struct AuthSessionEvent: Sendable {
    public let user: AuthUser?
    public let isPasswordRecovery: Bool
    public init(user: AuthUser?, isPasswordRecovery: Bool = false) {
        self.user = user
        self.isPasswordRecovery = isPasswordRecovery
    }
}
