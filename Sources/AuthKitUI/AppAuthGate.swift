import SwiftUI
import AuthKit
import Supabase

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

/// Keep this gate at the app root so observation survives login-view dismissal.
@MainActor
public struct AppAuthGate<Content: View>: View {
    private let configuration: AppAuthConfiguration?
    private let brand: AuthBrand
    private let onSignedOut: () -> Void
    private let content: (AuthUser, SessionManager) -> Content

    public init(brand: AuthBrand, configuration: AppAuthConfiguration? = .fromBundle(),
                onSignedOut: @escaping () -> Void = {},
                @ViewBuilder content: @escaping (AuthUser, SessionManager) -> Content) {
        self.configuration = configuration; self.brand = brand
        self.onSignedOut = onSignedOut; self.content = content
    }
    public var body: some View {
        if let configuration {
            ConfiguredAuthGate(brand: brand, configuration: configuration,
                               onSignedOut: onSignedOut, content: content)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.exclamationmark").font(.largeTitle)
                Text("Sign-in is unavailable").font(.headline)
                Text("Please try again later.").foregroundStyle(.secondary)
                #if DEBUG
                Text("Set the Supabase URL, publishable key and callback in the app configuration.")
                    .font(.caption).multilineTextAlignment(.center)
                #endif
            }.padding()
        }
    }
}

@MainActor
private struct ConfiguredAuthGate<Content: View>: View {
    let brand: AuthBrand
    let configuration: AppAuthConfiguration
    let onSignedOut: () -> Void
    let content: (AuthUser, SessionManager) -> Content
    @StateObject private var session: SessionManager
    @State private var accountPresented = false
    @State private var showingDeleteConfirmation = false

    init(brand: AuthBrand, configuration: AppAuthConfiguration,
         onSignedOut: @escaping () -> Void, content: @escaping (AuthUser, SessionManager) -> Content) {
        self.brand = brand; self.configuration = configuration
        self.onSignedOut = onSignedOut; self.content = content
        let manager = SupabaseManager(url: configuration.projectURL, publishableKey: configuration.publishableKey,
            authOptions: .init(redirectToURL: configuration.callbackURL, storageKey: configuration.storageKey))
        _session = StateObject(wrappedValue: SessionManager(authService: AuthService(backend: SupabaseAuthBackend(manager: manager))))
    }
    var body: some View {
        Group {
            if session.isPasswordRecovery {
                authView
            } else {
                switch session.state {
                case .loading: ProgressView("Restoring session")
                case .unauthenticated: authView
                case .authenticated(let user):
                    content(user, session).id(user.id)
                        .safeAreaInset(edge: .bottom) {
                            Button { accountPresented = true } label: {
                                Label("Account", systemImage: "person.crop.circle")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .background(.regularMaterial)
                            .accessibilityIdentifier("auth.account")
                        }
                        .sheet(isPresented: $accountPresented) {
                            NavigationStack {
                                Form {
                                    Text(user.email ?? "Signed in")
                                        .accessibilityIdentifier("auth.accountEmail")
                                    NavigationLink("Reset password") {
                                        AuthView(session: session, brand: brand, redirectTo: configuration.callbackURL,
                                                 initialScreen: .passwordReset, initialEmail: user.email ?? "")
                                            .navigationTitle("Reset password")
                                    }
                                    .accessibilityIdentifier("auth.accountResetPassword")
                                    .disabled(session.isLoading)
                                    if let error = session.errorMessage { Text(error).foregroundStyle(.red) }
                                    Button("Sign out", role: .destructive) {
                                        Task {
                                            await session.signOut()
                                            if session.state == .unauthenticated { accountPresented = false }
                                        }
                                    }.disabled(session.isLoading)
                                    .accessibilityIdentifier("auth.signOut")

                                    Section {
                                        Button("Delete account", role: .destructive) {
                                            showingDeleteConfirmation = true
                                        }
                                        .disabled(session.isLoading)
                                        .accessibilityIdentifier("auth.deleteAccount")
                                    } footer: {
                                        Text("Permanently deletes your account credentials and associated cloud records across this portfolio.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .navigationTitle("Account")
                                .toolbar { Button("Done") { accountPresented = false } }
                                .confirmationDialog(
                                    "Delete Account?",
                                    isPresented: $showingDeleteConfirmation,
                                    titleVisibility: .visible
                                ) {
                                    Button("Delete Account Permanently", role: .destructive) {
                                        Task {
                                            await session.deleteAccount()
                                            if session.state == .unauthenticated {
                                                accountPresented = false
                                            }
                                        }
                                    }
                                    Button("Cancel", role: .cancel) { }
                                } message: {
                                    Text("This will permanently remove your cloud identity and records. You cannot undo this action.")
                                }
                            }
                        }
                }
            }
        }
        .task { await session.observeAuthChanges() }
        .onChange(of: session.state) { state in
            if state == .unauthenticated { accountPresented = false; onSignedOut() }
        }
        .onChange(of: session.isPasswordRecovery) { recovering in
            if recovering { accountPresented = false }
        }
        .onOpenURL { url in
            guard configuration.accepts(url) else { return }
            // The SDK owns an in-flight browser OAuth callback exchange.
            guard !session.isLoading else { return }
            Task { await session.handleCallback(url) }
        }
    }
    private var authView: some View {
        AuthView(session: session, brand: brand, redirectTo: configuration.callbackURL,
                 providers: configuration.providers)
    }
}
