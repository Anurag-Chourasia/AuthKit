#if canImport(UIKit)
import UIKit
import SwiftUI
import XCTest
import AuthKit
@testable import AuthKitUI

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
    func deleteAccount() async throws { }
}

@MainActor
final class AuthViewRenderingTests: XCTestCase {
    func testAllBrandLayoutsRenderAtAccessibilitySize() async throws {
        let callback = try XCTUnwrap(URL(string: "preview-auth://auth/callback"))
        for brand in AuthBrand.allCases {
            let session = SessionManager(authService: AuthService(backend: PreviewBackend()))
            let view = AuthView(session: session, brand: brand,
                redirectTo: callback, providers: AuthProvider.allCases).formContent
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .frame(width: 414)
                .background(Color.white)
            // Layout-only evidence: ImageRenderer substitutes placeholders for UIKit text inputs.
            // Use Examples/AuthKitDemo to inspect and interact with the actual fields.
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            let cgImage = try XCTUnwrap(image.cgImage)
            let pixels = try XCTUnwrap(cgImage.dataProvider?.data) as Data
            XCTAssertGreaterThan(Set(pixels).count, 8, "A blank image must not pass UI validation")
            let attachment = XCTAttachment(image: image)
            attachment.name = brand.rawValue + "-accessibility"
            attachment.lifetime = .keepAlways
            add(attachment)
            if ProcessInfo.processInfo.environment["CI"] == nil {
                try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/authkit-\(brand.rawValue).png"))
            }
        }
    }
}
#endif
