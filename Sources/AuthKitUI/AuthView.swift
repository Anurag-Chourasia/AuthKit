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
    var tint: Color {
        switch self { case .myTV: .blue; case .showBook: .indigo; case .motivationDaily: .orange }
    }
}

@MainActor
public struct AuthView: View {
    @ObservedObject private var session: SessionManager
    private let brand: AuthBrand
    private let redirectTo: URL
    private let providers: [AuthProvider]
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    private enum Mode: String { case login = "Sign in", signup = "Create account", forgot = "Reset password" }

    public init(session: SessionManager, brand: AuthBrand, redirectTo: URL,
                providers: [AuthProvider] = []) {
        self.session = session; self.brand = brand; self.redirectTo = redirectTo; self.providers = providers
    }

    public var body: some View {
        ScrollView { formContent }
            .tint(brand.tint)
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
                            }
                        }
                        if let error = session.errorMessage { Text(error).foregroundStyle(.red).accessibilityIdentifier("auth.error") }
                        if let notice = session.notice { Text(notice).accessibilityIdentifier("auth.notice") }
                        Button(session.isPasswordRecovery ? "Update password" : mode.rawValue) {
                            Task { await submit() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSubmit || session.isLoading)
                        .accessibilityIdentifier("auth.submit")
                        if session.isLoading { ProgressView("Please wait") }
                    }
                    .textFieldStyle(.roundedBorder)
                }
                if !session.isPasswordRecovery {
                    if mode == .login {
                        Button("Forgot password?") { changeMode(.forgot) }
                        ForEach(providers, id: \.self) { provider in
                            Button("Continue with \(provider.displayName)") {
                                password = ""; confirmation = ""
                                Task { await session.signIn(provider: provider, redirectTo: redirectTo) }
                            }
                            .buttonStyle(.bordered).disabled(session.isLoading)
                        }
                    }
                    Button(mode == .login ? "Create an account" : "Back to sign in") {
                        changeMode(mode == .login ? .signup : .login)
                    }
                    .disabled(session.isLoading)
                }
            }
            .padding(Spacing.twenty)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .tint(brand.tint)
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
