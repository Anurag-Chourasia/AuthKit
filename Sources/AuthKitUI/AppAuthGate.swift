import SwiftUI
import AuthKit
import DesignTokensKit
import UIComponentsKit

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
            VStack(spacing: Spacing.sixteen) {
                Image(systemName: \.personCropCircleBadgeExclamationmark).font(.largeTitle)
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
                        .toolbar {
                            #if os(iOS)
                            AccountToolbarItem(session: session, placement: .topBarTrailing, localizer: localizer)
                            #else
                            AccountToolbarItem(session: session, placement: .automatic, localizer: localizer)
                            #endif
                        }
                        .sheet(isPresented: $session.isAccountPresented) {
                            AccountSheetView(
                                user: user,
                                session: session,
                                brand: brand,
                                configuration: configuration,
                                localizer: localizer,
                                onSignedOut: onSignedOut,
                                isPresented: $session.isAccountPresented
                            )
                        }
                }
            }
        }
        .environment(\.layoutDirection, localizer.isRightToLeft ? .rightToLeft : .leftToRight)
        .task { await session.observeAuthChanges() }
        .onChange(of: session.state) { state in
            if state == .unauthenticated { session.isAccountPresented = false; onSignedOut() }
        }
        .onChange(of: session.isPasswordRecovery) { recovering in
            if recovering { session.isAccountPresented = false }
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

/// Top navigation bar toolbar item for displaying and presenting the account sheet.
public struct AccountToolbarItem: ToolbarContent {
    @ObservedObject private var session: SessionManager
    private let localizer: any AuthLocalizing
    private let placement: ToolbarItemPlacement
    private let action: (() -> Void)?

    #if os(iOS)
    public init(session: SessionManager,
                placement: ToolbarItemPlacement = .topBarTrailing,
                localizer: (any AuthLocalizing)? = nil,
                action: (() -> Void)? = nil) {
        self.session = session
        self.placement = placement
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.action = action
    }
    #else
    public init(session: SessionManager,
                placement: ToolbarItemPlacement = .automatic,
                localizer: (any AuthLocalizing)? = nil,
                action: (() -> Void)? = nil) {
        self.session = session
        self.placement = placement
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.action = action
    }
    #endif

    public var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            Button {
                if let action {
                    action()
                } else {
                    session.showAccount()
                }
            } label: {
                Image(systemName: \.personCropCircle)
            }
            .accessibilityLabel(localizer.string("account.title"))
            .accessibilityIdentifier(.authAccount)
        }
    }
}

/// Standalone account button view with accessibility identifier .authAccount.
public struct AccountButton: View {
    @ObservedObject private var session: SessionManager
    private let localizer: any AuthLocalizing
    private let action: (() -> Void)?

    public init(session: SessionManager,
                localizer: (any AuthLocalizing)? = nil,
                action: (() -> Void)? = nil) {
        self.session = session
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.action = action
    }

    public var body: some View {
        Button {
            if let action {
                action()
            } else {
                session.showAccount()
            }
        } label: {
            Image(systemName: \.personCropCircle)
        }
        .accessibilityLabel(localizer.string("account.title"))
        .accessibilityIdentifier(.authAccount)
    }
}

/// Account profile and settings sheet presented upon account trigger.
public struct AccountSheetView: View {
    let user: AuthUser
    @ObservedObject var session: SessionManager
    let brand: AuthBrand
    let configuration: AppAuthConfiguration
    let localizer: any AuthLocalizing
    let onSignedOut: () -> Void
    @Binding var isPresented: Bool
    @State private var showingDeleteConfirmation = false

    public init(user: AuthUser,
                session: SessionManager,
                brand: AuthBrand,
                configuration: AppAuthConfiguration,
                localizer: (any AuthLocalizing)? = nil,
                onSignedOut: @escaping () -> Void = {},
                isPresented: Binding<Bool>) {
        self.user = user
        self.session = session
        self.brand = brand
        self.configuration = configuration
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.onSignedOut = onSignedOut
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            Form {
                Text(user.email ?? localizer.string("account.signed_in"))
                    .accessibilityIdentifier(.authAccountEmail)
                NavigationLink(localizer.string("auth.title.reset_password")) {
                    AuthView(session: session, brand: brand, redirectTo: configuration.callbackURL,
                             initialScreen: .passwordReset, initialEmail: user.email ?? "",
                             localizer: localizer)
                        .navigationTitle(localizer.string("auth.title.reset_password"))
                }
                .accessibilityIdentifier(.authAccountResetPassword)
                .disabled(session.isLoading)
                if let errorKey = session.semanticError?.localizationKey ?? session.errorMessage {
                    Text(localizer.string(errorKey)).foregroundStyle(.red)
                }
                Button(localizer.string("auth.button.sign_out"), role: .destructive) {
                    Task {
                        await session.signOut()
                        if session.state == .unauthenticated {
                            isPresented = false
                            onSignedOut()
                        }
                    }
                }.disabled(session.isLoading)
                .accessibilityIdentifier(.authSignOut)

                Section {
                    Button(localizer.string("auth.button.delete_account"), role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .disabled(session.isLoading)
                    .accessibilityIdentifier(.authDeleteAccount)
                } footer: {
                    Text(localizer.string("account.delete_footer_notice"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(localizer.string("account.title"))
            .toolbar { Button(localizer.string("account.done")) { isPresented = false } }
            .confirmationDialog(
                localizer.string("account.delete_confirmation_title"),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(localizer.string("account.delete_confirmation_action"), role: .destructive) {
                    Task {
                        await session.deleteAccount()
                        if session.state == .unauthenticated {
                            isPresented = false
                            onSignedOut()
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
