import SwiftUI
import XCTest
import AuthKit
@testable import AuthKitUI

private actor MockUserSettingsBackend: AuthBackend {
    var didSignOut = false
    var didDeleteAccount = false

    func currentUser() async throws -> AuthUser? {
        AuthUser(id: UUID(), email: "test@example.com")
    }
    func events() async -> AsyncStream<AuthSessionEvent> {
        AsyncStream { $0.finish() }
    }
    func signIn(email: String, password: String) async throws -> AuthUser {
        AuthUser(id: UUID(), email: email)
    }
    func signUp(email: String, password: String) async throws -> Bool { true }
    func signOut() async throws { didSignOut = true }
    func refreshSession() async throws {}
    func requestPasswordReset(email: String, redirectTo: URL) async throws {}
    func updatePassword(_ password: String) async throws {}
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser {
        AuthUser(id: UUID(), email: nil)
    }
    func handleCallback(_ url: URL) async throws -> AuthUser {
        AuthUser(id: UUID(), email: nil)
    }
    func deleteAccount() async throws { didDeleteAccount = true }
}

@MainActor
final class UserSettingsTests: XCTestCase {
    func testAboutConfigurationEqualityAndProperties() {
        var profileOpened = false
        let config1 = UserSettingsAboutConfiguration(
            appName: "MyTV",
            version: "1.0.0",
            build: "42",
            disclaimerTitle: "Disclaimer",
            disclaimerText: "Demo app",
            developerProfileTitle: "Developer",
            onOpenDeveloperProfile: { profileOpened = true }
        )
        let config2 = UserSettingsAboutConfiguration(
            appName: "MyTV",
            version: "1.0.0",
            build: "42",
            disclaimerTitle: "Disclaimer",
            disclaimerText: "Demo app",
            developerProfileTitle: "Developer",
            onOpenDeveloperProfile: nil
        )

        XCTAssertEqual(config1, config2)
        XCTAssertEqual(config1.appName, "MyTV")
        XCTAssertEqual(config1.version, "1.0.0")
        XCTAssertEqual(config1.build, "42")
        config1.onOpenDeveloperProfile?()
        XCTAssertTrue(profileOpened)
    }

    func testAccountSectionActions() {
        var signedOut = false
        var deleteRequested = false
        let user = AuthUser(id: UUID(), email: "user@example.com")

        let section = UserSettingsAccountSection(
            user: user,
            isLoading: false,
            onSignOut: { signedOut = true },
            onDeleteAccount: { deleteRequested = true }
        )

        XCTAssertNotNil(section.body)
        section.onSignOut()
        section.onDeleteAccount()
        XCTAssertTrue(signedOut)
        XCTAssertTrue(deleteRequested)

        let guestSection = UserSettingsAccountSection(
            user: nil,
            isLoading: true,
            onSignOut: {},
            onDeleteAccount: {}
        )
        XCTAssertNotNil(guestSection.body)
    }

    func testAboutSectionRendering() {
        var developerProfileOpened = false
        let config = UserSettingsAboutConfiguration(
            appName: "ShowBook",
            version: "2.1.0",
            build: "100",
            disclaimerTitle: "Important",
            disclaimerText: "Powered by Open Library",
            developerProfileTitle: "Know Developer",
            onOpenDeveloperProfile: { developerProfileOpened = true }
        )

        let section = UserSettingsAboutSection(configuration: config)
        XCTAssertNotNil(section.body)
        config.onOpenDeveloperProfile?()
        XCTAssertTrue(developerProfileOpened)
    }

    func testUserSettingsViewRenderingAndCallbacks() async {
        let backend = MockUserSettingsBackend()
        let session = SessionManager(authService: AuthService(backend: backend))
        await session.restoreSession()

        var signedOut = false
        var deleteRequested = false

        let viewFromSession = UserSettingsView(
            session: session,
            aboutConfiguration: UserSettingsAboutConfiguration(
                appName: "App",
                version: "1.0",
                build: "1"
            ),
            onSignedOut: { signedOut = true },
            onDeleteAccountRequested: { deleteRequested = true }
        ) {
            Text("Extra Section")
        }

        XCTAssertNotNil(viewFromSession.body)
        viewFromSession.onSignOut()
        viewFromSession.onDeleteAccount()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(signedOut)
        XCTAssertTrue(deleteRequested)

        let viewDirect = UserSettingsView(
            user: AuthUser(id: UUID(), email: "direct@example.com"),
            isLoading: false,
            aboutConfiguration: nil,
            onSignOut: { signedOut = true },
            onDeleteAccount: { deleteRequested = true }
        )
        XCTAssertNotNil(viewDirect.body)
    }

    func testUserSettingsSheetAndConvenienceModifiers() async {
        let backend = MockUserSettingsBackend()
        let session = SessionManager(authService: AuthService(backend: backend))
        await session.restoreSession()

        var dismissed = false
        let sheetWithDev = UserSettingsSheet(
            session: session,
            aboutConfiguration: UserSettingsAboutConfiguration(
                appName: "TestApp",
                version: "1.0",
                build: "1"
            ),
            onDismiss: { dismissed = true },
            additionalContent: {
                Text("Custom Settings Row")
            },
            developerContent: {
                Text("Developer Profile Screen")
            }
        )

        XCTAssertNotNil(sheetWithDev.body)
        sheetWithDev.onDismiss()
        XCTAssertTrue(dismissed)

        var directDismissed = false
        let sheetDirect = UserSettingsSheet(
            user: AuthUser(id: UUID(), email: "direct@example.com"),
            isLoading: false,
            aboutConfiguration: nil,
            onSignOut: {},
            onDeleteAccount: {},
            onDismiss: { directDismissed = true }
        )
        XCTAssertNotNil(sheetDirect.body)
        sheetDirect.onDismiss()
        XCTAssertTrue(directDismissed)

        let sheetNoDev = UserSettingsSheet(
            session: session,
            aboutConfiguration: nil,
            onDismiss: {}
        )
        XCTAssertNotNil(sheetNoDev.body)

        let modifiedView = Text("Host Screen")
            .userSettingsSheet(
                isPresented: .constant(true),
                session: session
            ) {
                Text("Additions")
            }
        XCTAssertNotNil(modifiedView)
    }
}
