import SwiftUI
import AuthKit

public typealias AuthBackendFactory = @Sendable (AppAuthConfiguration) -> any AuthBackend

/// Keep this gate at the app root so observation survives login-view dismissal.
@MainActor
public struct AppAuthGate<Content: View>: View {
    private let configuration: AppAuthConfiguration?
    private var configurationProvider: (any AuthConfigurationProviding)?
    private let backendFactory: AuthBackendFactory?
    @State private var dynamicConfiguration: AppAuthConfiguration?
    @State private var checkedReadiness = false
    private let brand: AuthBrand
    private let localizer: any AuthLocalizing
    private let onSignedOut: () -> Void
    private let content: (AuthUser, SessionManager) -> Content

    public init(brand: AuthBrand,
                configuration: AppAuthConfiguration? = .fromBundle(),
                backendFactory: AuthBackendFactory? = nil,
                localizer: (any AuthLocalizing)? = nil,
                onSignedOut: @escaping () -> Void = {},
                @ViewBuilder content: @escaping (AuthUser, SessionManager) -> Content) {
        self.configuration = configuration
        self.backendFactory = backendFactory
        self.brand = brand
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.onSignedOut = onSignedOut
        self.content = content
    }

    public init(brand: AuthBrand,
                configurationProvider: any AuthConfigurationProviding,
                backendFactory: AuthBackendFactory? = nil,
                localizer: (any AuthLocalizing)? = nil,
                onSignedOut: @escaping () -> Void = {},
                @ViewBuilder content: @escaping (AuthUser, SessionManager) -> Content) {
        self.init(brand: brand, configuration: nil, backendFactory: backendFactory, localizer: localizer,
                  onSignedOut: onSignedOut, content: content)
        self.configurationProvider = configurationProvider
    }

    public var body: some View {
        Group {
            if configurationProvider != nil && !checkedReadiness {
                ProgressView(localizer.string("auth.status.please_wait"))
            } else { configuredBody }
        }
        .task {
            guard let configurationProvider else { return }
            let resolved = try? await configurationProvider.configuration()
            guard !Task.isCancelled else { return }
            dynamicConfiguration = resolved
            checkedReadiness = true
        }
    }

    @ViewBuilder private var configuredBody: some View {
        if let configuration = configurationProvider == nil ? configuration : dynamicConfiguration,
           let backendFactory {
            ConfiguredAuthGate(brand: brand, configuration: configuration,
                               backendFactory: backendFactory,
                               localizer: localizer,
                               onSignedOut: onSignedOut, content: content)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.exclamationmark").font(.largeTitle)
                Text(localizer.string("auth.unavailable.title")).font(.headline)
                Text(localizer.string("auth.unavailable.message")).foregroundStyle(.secondary)
                #if DEBUG
                Text(localizer.string("auth.unavailable.debug_configuration"))
                    .font(.caption).multilineTextAlignment(.center)
                #endif
            }.padding()
            .environment(\.layoutDirection, localizer.isRightToLeft ? .rightToLeft : .leftToRight)
        }
    }
}

@MainActor
private struct ConfiguredAuthGate<Content: View>: View {
    let brand: AuthBrand
    let configuration: AppAuthConfiguration
    let localizer: any AuthLocalizing
    let onSignedOut: () -> Void
    let content: (AuthUser, SessionManager) -> Content
    @StateObject private var session: SessionManager
    @State private var accountPresented = false
    @State private var showingDeleteConfirmation = false

    init(brand: AuthBrand, configuration: AppAuthConfiguration,
         backendFactory: AuthBackendFactory,
         localizer: any AuthLocalizing,
         onSignedOut: @escaping () -> Void, content: @escaping (AuthUser, SessionManager) -> Content) {
        self.brand = brand; self.configuration = configuration
        self.localizer = localizer
        self.onSignedOut = onSignedOut; self.content = content
        let backend = backendFactory(configuration)
        _session = StateObject(wrappedValue: SessionManager(authService: AuthService(backend: backend)))
    }
    var body: some View {
        Group {
            if session.isPasswordRecovery {
                authView
            } else {
                switch session.state {
                case .loading: ProgressView(localizer.string("auth.status.please_wait"))
                case .unauthenticated: authView
                case .authenticated(let user):
                    content(user, session).id(user.id)
                        .safeAreaInset(edge: .bottom) {
                            Button { accountPresented = true } label: {
                                Label(localizer.string("account.title"), systemImage: "person.crop.circle")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .background(.regularMaterial)
                            .accessibilityIdentifier("auth.account")
                        }
                        .sheet(isPresented: $accountPresented) {
                            NavigationStack {
                                Form {
                                    Text(user.email ?? localizer.string("account.signed_in"))
                                        .accessibilityIdentifier("auth.accountEmail")
                                    NavigationLink(localizer.string("auth.title.reset_password")) {
                                        AuthView(session: session, brand: brand, redirectTo: configuration.callbackURL,
                                                 initialScreen: .passwordReset, initialEmail: user.email ?? "",
                                                 localizer: localizer)
                                            .navigationTitle(localizer.string("auth.title.reset_password"))
                                    }
                                    .accessibilityIdentifier("auth.accountResetPassword")
                                    .disabled(session.isLoading)
                                    if let errorKey = session.semanticError?.localizationKey ?? session.errorMessage {
                                        Text(localizer.string(errorKey)).foregroundStyle(.red)
                                    }
                                    Button(localizer.string("auth.button.sign_out"), role: .destructive) {
                                        Task {
                                            await session.signOut()
                                            if session.state == .unauthenticated { accountPresented = false }
                                        }
                                    }.disabled(session.isLoading)
                                    .accessibilityIdentifier("auth.signOut")

                                    Section {
                                        Button(localizer.string("auth.button.delete_account"), role: .destructive) {
                                            showingDeleteConfirmation = true
                                        }
                                        .disabled(session.isLoading)
                                        .accessibilityIdentifier("auth.deleteAccount")
                                    } footer: {
                                        Text(localizer.string("account.delete_footer_notice"))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .navigationTitle(localizer.string("account.title"))
                                .toolbar { Button(localizer.string("account.done")) { accountPresented = false } }
                                .confirmationDialog(
                                    localizer.string("account.delete_confirmation_title"),
                                    isPresented: $showingDeleteConfirmation,
                                    titleVisibility: .visible
                                ) {
                                    Button(localizer.string("account.delete_confirmation_action"), role: .destructive) {
                                        Task {
                                            await session.deleteAccount()
                                            if session.state == .unauthenticated {
                                                accountPresented = false
                                            }
                                        }
                                    }
                                    Button(localizer.string("common.cancel"), role: .cancel) { }
                                } message: {
                                    Text(localizer.string("account.delete_confirmation_message"))
                                }
                            }
                            .environment(\.layoutDirection, localizer.isRightToLeft ? .rightToLeft : .leftToRight)
                        }
                }
            }
        }
        .environment(\.layoutDirection, localizer.isRightToLeft ? .rightToLeft : .leftToRight)
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
                 providers: configuration.providers, localizer: localizer)
    }
}
