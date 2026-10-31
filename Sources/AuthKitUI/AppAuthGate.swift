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

    public init(projectURL: URL, publishableKey: String, callbackURL: URL,
                storageKey: String, providers: [AuthProvider] = []) {
        self.projectURL = projectURL; self.publishableKey = publishableKey
        self.callbackURL = callbackURL; self.storageKey = storageKey; self.providers = providers
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> AppAuthConfiguration? {
        guard let address = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: address), url.scheme == "https", url.host != nil,
              let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty, !key.contains("$("),
              let redirect = bundle.object(forInfoDictionaryKey: "AUTH_CALLBACK_URL") as? String,
              let callback = URL(string: redirect), callback.scheme != nil,
              let bundleID = bundle.bundleIdentifier else { return nil }
        let names = (bundle.object(forInfoDictionaryKey: "AUTH_PROVIDERS") as? String ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return .init(projectURL: url, publishableKey: key, callbackURL: callback,
                     storageKey: bundleID + ".supabase.session", providers: names.compactMap(AuthProvider.init(rawValue:)))
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
                        }
                        .sheet(isPresented: $accountPresented) {
                            NavigationStack {
                                Form {
                                    Text(user.email ?? "Signed in")
                                    if let error = session.errorMessage { Text(error).foregroundStyle(.red) }
                                    Button("Sign out", role: .destructive) {
                                        Task {
                                            await session.signOut()
                                            if session.state == .unauthenticated { accountPresented = false }
                                        }
                                    }.disabled(session.isLoading)
                                }
                                .navigationTitle("Account")
                                .toolbar { Button("Done") { accountPresented = false } }
                            }
                        }
                }
            }
        }
        .task { await session.observeAuthChanges() }
        .onChange(of: session.state) { state in
            if state == .unauthenticated { accountPresented = false; onSignedOut() }
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
