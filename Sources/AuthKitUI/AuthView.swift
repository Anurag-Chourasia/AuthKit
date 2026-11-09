import SwiftUI
import AuthKit
import DesignTokensKit
import UIComponentsKit

/// Shared auth surface with app-owned identity. Provider buttons should only include
/// providers enabled in Supabase. Apple uses the Supabase browser OAuth flow.
public enum AuthBrand: String, CaseIterable, Sendable {
    case myTV, showBook, motivationDaily
    public var title: String {
        switch self { case .myTV: "MyTV"; case .showBook: "ShowBook"; case .motivationDaily: "Motivation Daily" }
    }
    var symbol: String {
        switch self { case .myTV: "play.tv"; case .showBook: "books.vertical"; case .motivationDaily: "sun.max" }
    }
    public var appBrand: AppBrand {
        switch self {
        case .myTV: return .myTV
        case .showBook: return .showBook
        case .motivationDaily: return .motivationDaily
        }
    }
    public var palette: BrandPalette {
        BrandPalette.palette(for: appBrand)
    }
    func localizedSubtitle(using localizer: any AuthLocalizing) -> String {
        switch self {
        case .myTV:
            return localizer.string("auth.brand.mytv.subtitle")
        case .showBook:
            return localizer.string("auth.brand.showbook.subtitle")
        case .motivationDaily:
            return localizer.string("auth.brand.motivation_daily.subtitle")
        }
    }
}

public enum AuthScreen: Sendable { case login, passwordReset }

@MainActor
public struct AuthView: View {
    @ObservedObject private var session: SessionManager
    private let brand: AuthBrand
    private let palette: BrandPalette
    private let redirectTo: URL
    private let providers: [AuthProvider]
    private let initialScreen: AuthScreen
    private let localizer: any AuthLocalizing
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""

    private enum Mode: String {
        case login, signup, forgot
        func localizedTitle(using localizer: any AuthLocalizing) -> String {
            switch self {
            case .login: return localizer.string("auth.title.sign_in")
            case .signup: return localizer.string("auth.title.create_account")
            case .forgot: return localizer.string("auth.title.reset_password")
            }
        }
    }

    public init(session: SessionManager, brand: AuthBrand, redirectTo: URL,
                providers: [AuthProvider] = [], palette: BrandPalette? = nil,
                initialScreen: AuthScreen = .login, initialEmail: String = "",
                localizer: (any AuthLocalizing)? = nil) {
        self.palette = palette ?? brand.palette
        self.session = session; self.brand = brand; self.redirectTo = redirectTo; self.providers = providers
        self.initialScreen = initialScreen
        self.localizer = localizer ?? DefaultAuthLocalizer()
        _mode = State(initialValue: initialScreen == .passwordReset ? .forgot : .login)
        _email = State(initialValue: initialEmail)
    }

    @available(*, deprecated, message: "Use init with BrandPalette instead of AuthPalette.")
    public init(session: SessionManager, brand: AuthBrand, redirectTo: URL,
                providers: [AuthProvider] = [], palette: AuthPalette,
                initialScreen: AuthScreen = .login, initialEmail: String = "",
                localizer: (any AuthLocalizing)? = nil) {
        self.init(
            session: session,
            brand: brand,
            redirectTo: redirectTo,
            providers: providers,
            palette: palette.brandPalette,
            initialScreen: initialScreen,
            initialEmail: initialEmail,
            localizer: localizer
        )
    }

    public var body: some View {
        ScrollView { formContent }
            .foregroundStyle(palette.authForeground)
            .background(palette.authBackground)
            .tint(palette.authAction)
            .environment(\.layoutDirection, localizer.isRightToLeft ? .rightToLeft : .leftToRight)
            .onAuthValueChange(of: session.isPasswordRecovery) { _ in password = ""; confirmation = "" }
            .onDisappear { password = ""; confirmation = "" }
    }

    private var submitTitle: String {
        if session.isPasswordRecovery {
            return localizer.string("auth.title.choose_new_password")
        }
        if mode == .forgot {
            return localizer.string("auth.title.reset_password")
        }
        return mode.localizedTitle(using: localizer)
    }

    // Renderable content is separate from the platform-backed scrolling container.
    var formContent: some View {
            VStack(spacing: \.twenty) {
                Image(systemName: brand.symbol).font(.largeTitle).accessibilityHidden(true)
                Text(brand.title).font(.largeTitle.bold())
                Text(brand.localizedSubtitle(using: localizer)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                SurfaceCard {
                    VStack(alignment: .leading, spacing: \.sixteen) {
                        Text(session.isPasswordRecovery ? localizer.string("auth.title.choose_new_password") : mode.localizedTitle(using: localizer)).font(.title2.bold())
                        if !session.isPasswordRecovery {
                            if mode == .forgot {
                                Text(localizer.string("auth.instruction.reset_email_sent"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            TextField(localizer.string("auth.field.email"), text: $email)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                #endif
                                .accessibilityIdentifier(.authEmail)
                        }
                        if session.isPasswordRecovery || mode != .forgot {
                            SecureField(localizer.string("auth.field.password"), text: $password)
                                .textContentType(mode == .login && !session.isPasswordRecovery ? .password : .newPassword)
                                .accessibilityIdentifier(.authPassword)
                            if mode == .signup || session.isPasswordRecovery {
                                SecureField(localizer.string("auth.field.confirm_password"), text: $confirmation).textContentType(.newPassword)
                                    .accessibilityIdentifier(.authConfirmPassword)
                                Text(localizer.string("auth.instruction.password_requirements"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let errorKey = session.semanticError?.localizationKey ?? session.errorMessage {
                            Text(localizer.string(errorKey)).foregroundStyle(.red).accessibilityIdentifier(.authError)
                        }
                        if let noticeKey = session.semanticNotice?.localizationKey ?? session.notice {
                            Text(localizer.string(noticeKey)).accessibilityIdentifier(.authNotice)
                        }
                        Button {
                            Task { await submit() }
                        } label: {
                            Text(submitTitle)
                                .font(.headline)
                                .frame(minHeight: \.touchTargetSpacious)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.authOnAction)
                        .background(palette.authAction, in: RoundedRectangle(cornerRadius: \.cardRadius))
                        .opacity(!canSubmit || session.isLoading ? \.p0_4 : \.p1_0)
                        .disabled(!canSubmit || session.isLoading)
                        .accessibilityIdentifier(.authSubmit)
                        if session.isLoading { ProgressView(localizer.string("auth.status.please_wait")) }
                    }
                    .textFieldStyle(.roundedBorder)
                }
                if !session.isPasswordRecovery && initialScreen == .login {
                    if mode == .login {
                        Button(localizer.string("auth.button.forgot_password")) { changeMode(.forgot) }
                            .accessibilityIdentifier(.authForgotPassword)
                            .disabled(session.isLoading)
                        if !providers.isEmpty {
                            HStack(spacing: \.twelve) {
                                Rectangle().frame(height: \.p1)
                                Text(localizer.string("auth.or_continue_with")).font(.caption).fixedSize()
                                Rectangle().frame(height: \.p1)
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                            VStack(spacing: \.twelve) {
                                ForEach(providers, id: \.self) { provider in
                                    ProviderSignInButton(provider: provider, isLoading: session.isLoading, localizer: localizer) {
                                        password = ""; confirmation = ""
                                        Task { await session.signIn(provider: provider, redirectTo: redirectTo) }
                                    }
                                }
                            }
                            .padding(.horizontal, \.sixteen)
                        }
                    }
                    Button(mode == .login ? localizer.string("auth.button.create_an_account") : localizer.string("auth.button.back_to_sign_in")) {
                        changeMode(mode == .login ? .signup : .login)
                    }
                    .disabled(session.isLoading)
                    .accessibilityIdentifier(.authSwitchMode)
                }
            }
            .padding(\.twenty)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .tint(palette.authAction)
    }

    private var canSubmit: Bool {
        if session.isPasswordRecovery { return password.count >= 8 && password == confirmation }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.contains("@"), !address.hasSuffix("@") else { return false }
        switch mode {
        case .forgot: return true
        case .login: return !password.isEmpty
        case .signup: return password.count >= 8 && password == confirmation
        }
    }
    private func changeMode(_ value: Mode) { mode = value; password = ""; confirmation = "" }
    private func submit() async {
        let secret = password
        password = ""; confirmation = ""
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if session.isPasswordRecovery { await session.updatePassword(secret); return }
        switch mode {
        case .login: await session.signIn(email: address, password: secret)
        case .signup: await session.signUp(email: address, password: secret)
        case .forgot: await session.requestPasswordReset(email: address, redirectTo: redirectTo)
        }
    }
}

extension View {
    @ViewBuilder
    func onAuthValueChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }
}

#if DEBUG
/// Preview-only backend keeps the canvas independent of Supabase credentials,
/// Keychain entitlements, network access and the example app target.
private actor AuthPreviewBackend: AuthBackend {
    func currentUser() async throws -> AuthUser? { nil }
    func events() async -> AsyncStream<AuthSessionEvent> {
        AsyncStream { $0.yield(.init(user: nil)); $0.finish() }
    }
    func signIn(email: String, password: String) async throws -> AuthUser { .init(id: UUID(), email: email) }
    func signUp(email: String, password: String) async throws -> Bool { true }
    func signOut() async throws { }
    func refreshSession() async throws { }
    func requestPasswordReset(email: String, redirectTo: URL) async throws { }
    func updatePassword(_ password: String) async throws { }
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser { throw URLError(.unsupportedURL) }
    func handleCallback(_ url: URL) async throws -> AuthUser { throw URLError(.unsupportedURL) }
    func deleteAccount() async throws { }
}

@MainActor
private struct AuthPreview: View {
    let brand: AuthBrand
    @StateObject private var session = SessionManager(
        authService: AuthService(backend: AuthPreviewBackend()))
    var body: some View {
        AuthView(session: session, brand: brand,
                 redirectTo: URL(string: "authkit-preview://auth/callback")!,
                 providers: AuthProvider.allCases)
    }
}

#Preview("ShowBook") { AuthPreview(brand: .showBook) }
#Preview("MyTV") { AuthPreview(brand: .myTV) }
#Preview("Motivation Daily") { AuthPreview(brand: .motivationDaily) }
#endif
