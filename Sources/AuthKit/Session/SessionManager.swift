import Foundation
import Combine

public enum AuthState: Equatable, Sendable {
    case loading
    case authenticated(AuthUser)
    case unauthenticated
}

/// Own one instance per app session. Operations are serialized: a second user intent
/// is rejected while an authentication request is active, including browser OAuth.
@MainActor
public final class SessionManager: ObservableObject {
    @Published public private(set) var state: AuthState = .loading
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var notice: String?
    @Published public private(set) var isPasswordRecovery = false
    private let authService: AuthService
    private var observation: Task<Void, Never>?
    private var revision = 0

    public init(authService: AuthService) { self.authService = authService }
    deinit { observation?.cancel() }

    /// Call from the host's root `.task`. Cancellation tears down the SDK listener.
    public func observeAuthChanges() async {
        observation?.cancel()
        let service = authService
        let task = Task { [weak self] in
            let stream = await service.events()
            for await event in stream {
                guard !Task.isCancelled, let self else { break }
                self.revision += 1
                self.state = event.user.map(AuthState.authenticated) ?? .unauthenticated
                if event.isPasswordRecovery { self.isPasswordRecovery = true }
                if event.user == nil { self.isPasswordRecovery = false }
            }
        }
        observation = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        notice = nil
        defer { isLoading = false }
        do { try await operation() }
        catch is CancellationError { }
        catch { errorMessage = error.localizedDescription }
    }

    public func restoreSession() async {
        await perform {
            let started = revision
            do {
                let user = try await authService.currentUser()
                if revision == started { state = user.map(AuthState.authenticated) ?? .unauthenticated }
            } catch {
                if revision == started { state = .unauthenticated }
                throw error
            }
        }
    }

    public func signIn(email: String, password: String) async {
        await perform {
            let started = revision
            do {
                let user = try await authService.signIn(email: email, password: password)
                if revision == started { state = .authenticated(user) }
            } catch {
                if revision == started { state = .unauthenticated }
                throw error
            }
        }
    }

    public func signUp(email: String, password: String) async {
        await perform {
            let confirmationRequired = try await authService.signUp(email: email, password: password)
            if confirmationRequired { notice = "Check your email to confirm your account." }
            else {
                let started = revision
                let user = try await authService.currentUser()
                if revision == started { state = user.map(AuthState.authenticated) ?? .unauthenticated }
            }
        }
    }

    public func signOut() async {
        await perform {
            let started = revision
            try await authService.signOut()
            if revision == started { state = .unauthenticated }
            isPasswordRecovery = false
        }
    }

    public func deleteAccount() async {
        await perform {
            let started = revision
            try await authService.deleteAccount()
            if revision == started { state = .unauthenticated }
            isPasswordRecovery = false
            notice = "Your account and associated cloud data have been deleted."
        }
    }

    public func signIn(provider: AuthProvider, redirectTo: URL) async {
        await perform {
            let started = revision
            let user = try await authService.signIn(provider: provider, redirectTo: redirectTo)
            if revision == started { state = .authenticated(user) }
        }
    }

    public func requestPasswordReset(email: String, redirectTo: URL) async {
        await perform {
            try await authService.requestPasswordReset(email: email, redirectTo: redirectTo)
            notice = "If an account exists, a reset link will be sent to your email."
        }
    }

    public func updatePassword(_ password: String) async {
        await perform {
            try await authService.updatePassword(password)
            isPasswordRecovery = false
            notice = "Your password has been updated."
        }
    }

    /// Host must first match the callback against its configured URL scheme/host/path.
    /// Browser OAuth consumes its own callback; forward email confirmation/recovery here.
    public func handleCallback(_ url: URL) async {
        await perform {
            let started = revision
            let user = try await authService.handleCallback(url)
            if revision == started { state = .authenticated(user) }
        }
    }
}
