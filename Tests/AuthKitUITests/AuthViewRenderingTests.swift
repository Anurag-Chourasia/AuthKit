#if canImport(UIKit)
import UIKit
import SwiftUI
import XCTest
import AuthKit
import AuthKitUI

private actor PreviewBackend: AuthBackend {
    func currentUser() async throws -> AuthUser? { nil }
    func events() async -> AsyncStream<AuthSessionEvent> { AsyncStream { $0.finish() } }
    func signIn(email: String, password: String) async throws -> AuthUser { AuthUser(id: UUID(), email: email) }
    func signUp(email: String, password: String) async throws -> Bool { true }
    func signOut() async throws { }
    func refreshSession() async throws { }
    func requestPasswordReset(email: String, redirectTo: URL) async throws { }
    func updatePassword(_ password: String) async throws { }
    func signIn(provider: AuthProvider, redirectTo: URL) async throws -> AuthUser { AuthUser(id: UUID(), email: nil) }
    func handleCallback(_ url: URL) async throws -> AuthUser { AuthUser(id: UUID(), email: nil) }
}

@MainActor
final class AuthViewRenderingTests: XCTestCase {
    func testAllBrandsRenderAtAccessibilitySize() throws {
        let callback = try XCTUnwrap(URL(string: "preview-auth://auth/callback"))
        for brand in AuthBrand.allCases {
            let session = SessionManager(authService: AuthService(backend: PreviewBackend()))
            let controller = UIHostingController(rootView: AuthView(session: session, brand: brand,
                redirectTo: callback, providers: AuthProvider.allCases)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 414, height: 896))
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.frame = window.bounds
            controller.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                controller.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertNotNil(image.cgImage)
            let attachment = XCTAttachment(image: image)
            attachment.name = brand.rawValue + "-accessibility"
            attachment.lifetime = .keepAlways
            add(attachment)
            if ProcessInfo.processInfo.environment["CI"] == nil {
                try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/authkit-\(brand.rawValue).png"))
            }
            window.isHidden = true
            window.rootViewController = nil
        }
    }
}
#endif
