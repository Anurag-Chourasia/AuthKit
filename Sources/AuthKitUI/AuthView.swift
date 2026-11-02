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
    var subtitle: String {
        switch self {
        case .myTV: "Your channels. Your favourites."
        case .showBook: "Your next chapter starts here."
        case .motivationDaily: "A little inspiration, every day."
        }
    }

}

public enum AuthScreen: Sendable { case login, passwordReset }

@MainActor
public struct AuthView: View {
    @ObservedObject private var session: SessionManager
    private let brand: AuthBrand
    private let palette: AuthPalette
    private let redirectTo: URL
    private let providers: [AuthProvider]
    private let initialScreen: AuthScreen
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    private enum Mode: String { case login = "Sign in", signup = "Create account", forgot = "Reset password" }

    public init(session: SessionManager, brand: AuthBrand, redirectTo: URL,
                providers: [AuthProvider] = [], palette: AuthPalette? = nil,
                initialScreen: AuthScreen = .login, initialEmail: String = "") {
        self.palette = palette ?? .appAssets(fallback: .projectDefault(for: brand))
        self.session = session; self.brand = brand; self.redirectTo = redirectTo; self.providers = providers
        self.initialScreen = initialScreen
        _mode = State(initialValue: initialScreen == .passwordReset ? .forgot : .login)
        _email = State(initialValue: initialEmail)
    }

    public var body: some View {
        ScrollView { formContent }
            .foregroundStyle(palette.foreground)
            .background(palette.background)
            .tint(palette.action)
            .onChange(of: session.isPasswordRecovery) { _ in password = ""; confirmation = "" }
            .onDisappear { password = ""; confirmation = "" }
    }

    // Renderable content is separate from the platform-backed scrolling container.
    var formContent: some View {
            VStack(spacing: Spacing.twenty) {
                Image(systemName: brand.symbol).font(.largeTitle).accessibilityHidden(true)
                Text(brand.title).font(.largeTitle.bold())
                Text(brand.subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.sixteen) {
                        Text(session.isPasswordRecovery ? "Choose a new password" : mode.rawValue).font(.title2.bold())
                        if !session.isPasswordRecovery {
                            if mode == .forgot {
                                Text("We’ll email you a link to choose a new password. Open it on this device.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                #endif
                                .accessibilityIdentifier("auth.email")
                        }
                        if session.isPasswordRecovery || mode != .forgot {
                            SecureField("Password", text: $password)
                                .textContentType(mode == .login && !session.isPasswordRecovery ? .password : .newPassword)
                                .accessibilityIdentifier("auth.password")
                            if mode == .signup || session.isPasswordRecovery {
                                SecureField("Confirm password", text: $confirmation).textContentType(.newPassword)
                                    .accessibilityIdentifier("auth.confirmPassword")
                                Text("Use at least 8 characters. Passwords must match.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let error = session.errorMessage { Text(error).foregroundStyle(.red).accessibilityIdentifier("auth.error") }
                        if let notice = session.notice { Text(notice).accessibilityIdentifier("auth.notice") }
                        Button {
                            Task { await submit() }
                        } label: {
                            Text(session.isPasswordRecovery ? "Update password" : mode == .forgot ? "Send reset link" : mode.rawValue)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.onAction)
                        .background(palette.action, in: RoundedRectangle(cornerRadius: CornerRadius.twelve))
                        .opacity(!canSubmit || session.isLoading ? 0.4 : 1)
                        .disabled(!canSubmit || session.isLoading)
                        .accessibilityIdentifier("auth.submit")
                        if session.isLoading { ProgressView("Please wait") }
                    }
                    .textFieldStyle(.roundedBorder)
                }
                if !session.isPasswordRecovery && initialScreen == .login {
                    if mode == .login {
                        Button("Forgot password?") { changeMode(.forgot) }
                            .accessibilityIdentifier("auth.forgotPassword")
                            .disabled(session.isLoading)
                        if !providers.isEmpty {
                            HStack(spacing: Spacing.twelve) {
                                Rectangle().frame(height: StrokeWidth.one)
                                Text("or continue with").font(.caption).fixedSize()
                                Rectangle().frame(height: StrokeWidth.one)
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                            VStack(spacing: Spacing.twelve) {
                                ForEach(providers, id: \.self) { provider in
                                    ProviderSignInButton(provider: provider, isLoading: session.isLoading) {
                                        password = ""; confirmation = ""
                                        Task { await session.signIn(provider: provider, redirectTo: redirectTo) }
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.sixteen)
                        }
                    }
                    Button(mode == .login ? "Create an account" : "Back to sign in") {
                        changeMode(mode == .login ? .signup : .login)
                    }
                    .disabled(session.isLoading)
                    .accessibilityIdentifier("auth.switchMode")
                }
            }
            .padding(Spacing.twenty)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .tint(palette.action)
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
