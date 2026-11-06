import Foundation

/// Host-owned configuration; contains only client-public configuration, never an admin key.
public struct AppAuthConfiguration: Sendable {
    public let projectURL: URL
    public let publishableKey: String
    public let callbackURL: URL
    public let storageKey: String
    public let providers: [AuthProvider]
    public let environment: AuthEnvironment

    public init(
        projectURL: URL,
        publishableKey: String,
        callbackURL: URL,
        storageKey: String,
        providers: [AuthProvider] = [],
        environment: AuthEnvironment = .production
    ) {
        self.projectURL = projectURL
        self.publishableKey = publishableKey
        self.callbackURL = callbackURL
        self.storageKey = storageKey
        self.providers = providers
        self.environment = environment
    }

    public static func fromBundle(
        _ bundle: Bundle = .main,
        environment: AuthEnvironment = .production
    ) -> AppAuthConfiguration? {
        let envPrefix = environment == .staging ? "STAGING_" : ""
        let address = (bundle.object(forInfoDictionaryKey: "SUPABASE_\(envPrefix)URL") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
        let key = (bundle.object(forInfoDictionaryKey: "SUPABASE_\(envPrefix)PUBLISHABLE_KEY") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String)

        guard let address,
              let url = URL(string: address), url.scheme == "https", url.host != nil,
              let key, !key.isEmpty, !key.contains("$("),
              let redirect = bundle.object(forInfoDictionaryKey: "AUTH_CALLBACK_URL") as? String,
              let callback = URL(string: redirect), callback.scheme != nil,
              let bundleID = bundle.bundleIdentifier else { return nil }
        let names = (bundle.object(forInfoDictionaryKey: "AUTH_PROVIDERS") as? String ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let storageSuffix = environment == .staging ? ".supabase.staging.session" : ".supabase.session"
        return .init(
            projectURL: url,
            publishableKey: key,
            callbackURL: callback,
            storageKey: bundleID + storageSuffix,
            providers: names.compactMap(AuthProvider.init(rawValue:)),
            environment: environment
        )
    }

    public func accepts(_ url: URL) -> Bool {
        url.scheme?.lowercased() == callbackURL.scheme?.lowercased()
        && url.host?.lowercased() == callbackURL.host?.lowercased()
        && url.path == callbackURL.path
    }
}

/// Supplies host-owned configuration after a dynamic backend-readiness check.
/// This is a rollout input; backend authorization remains server-enforced.
public protocol AuthConfigurationProviding: Sendable {
    func configuration() async throws -> AppAuthConfiguration?
}

/// Hosts inject readiness policy; offline/session policy is not guessed by the UI package.
public struct ReadinessCheckedAuthConfiguration: AuthConfigurationProviding {
    private let candidate: AppAuthConfiguration?
    private let isReady: @Sendable () async throws -> Bool

    public init(configuration: AppAuthConfiguration?, isReady: @escaping @Sendable () async throws -> Bool) {
        candidate = configuration
        self.isReady = isReady
    }

    public func configuration() async throws -> AppAuthConfiguration? {
        guard let candidate, try await isReady() else { return nil }
        return candidate
    }
}
