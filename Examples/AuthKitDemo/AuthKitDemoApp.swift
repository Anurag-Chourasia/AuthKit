import SwiftUI
import AuthKit
import AuthKitUI

private actor DemoBackend: AuthBackend {
    func currentUser() async throws -> AuthUser? { nil }
    func events() async -> AsyncStream<AuthSessionEvent> { AsyncStream { $0.yield(.init(user: nil)); $0.finish() } }
    func signIn(email: String, password: String) async throws -> AuthUser { AuthUser(id: UUID(), email: email) }
    func signUp(email: String, password: String) async throws -> Bool { true }
    func signOut() async throws { }
    func refreshSession() async throws { }
    func requestPasswordReset(email: String, redirectTo: URL) async throws { }
    func updatePassword(_ password: String) async throws { }
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser { throw URLError(.unsupportedURL) }
    func handleCallback(_ url: URL) async throws -> AuthUser { throw URLError(.unsupportedURL) }
}

@main
struct AuthKitDemoApp: App {
    @StateObject private var session = SessionManager(authService: AuthService(backend: DemoBackend()))
    @State private var brand: AuthBrand = .showBook
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Offline UI demo").font(.caption)
                Picker("App", selection: $brand) {
                    ForEach(AuthBrand.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).padding()
                AuthView(session: session, brand: brand,
                    redirectTo: URL(string: "authkit-demo://auth/callback")!,
                    providers: AuthProvider.allCases)
            }
            .task { await session.observeAuthChanges() }
        }
    }
}
