//
//  SupabaseAuthIntegrationTests.swift
//  AuthKit
//
//  Created by Anurag Chourasia on 31/10/26.
//

import Foundation
import XCTest
import Supabase
@testable import AuthKit

final class SupabaseAuthIntegrationTests: XCTestCase {

    func testRealAuthenticationLifecycle() async throws {

        // MARK: - Configuration

        let env = ProcessInfo.processInfo.environment

        guard
            let urlString = env["SUPABASE_URL"],
            let url = URL(string: urlString),
            let key = env["SUPABASE_PUBLISHABLE_KEY"],
            let email = env["SUPABASE_TEST_EMAIL"],
            let password = env["SUPABASE_TEST_PASSWORD"],
            !key.isEmpty,
            !email.isEmpty,
            !password.isEmpty
        else {
            throw XCTSkip(
                "Supabase environment variables missing"
            )
        }

        // MARK: - Setup

        let manager = SupabaseManager(
            url: url,
            publishableKey: key,
            authOptions: .init(storage: InMemoryAuthStorage(), storageKey: "authkit-integration-\(UUID())")
        )

        let backend = SupabaseAuthBackend(
            manager: manager
        )

        let sut = AuthService(backend: backend)

        // MARK: - 1. Sign In

        let user = try await sut.signIn(
            email: email,
            password: password
        )

        XCTAssertEqual(
            user.email?.lowercased(),
            email.lowercased()
        )

        // MARK: - 2. Current User

        let sessionUser = try await sut.currentUser()
        let currentUser = try XCTUnwrap(sessionUser)

        XCTAssertEqual(currentUser.id, user.id)

        // MARK: - 3. Refresh Session

        try await sut.refreshSession()

        let sessionUserAfterRefresh = try await sut.currentUser()
        let refreshedUser = try XCTUnwrap(sessionUserAfterRefresh)

        XCTAssertEqual(refreshedUser.id, user.id)

        // MARK: - 4. Sign Out

        try await sut.signOut()

        let signedOutUser = try await sut.currentUser()

        XCTAssertNil(signedOutUser)
    }

    func testSupabaseEnvironmentConfiguration() throws {

        let environment = ProcessInfo.processInfo.environment

        let requiredKeys = [
            "SUPABASE_URL",
            "SUPABASE_PUBLISHABLE_KEY",
            "SUPABASE_TEST_EMAIL",
            "SUPABASE_TEST_PASSWORD"
        ]

        let missingKeys = requiredKeys.filter {
            environment[$0]?.isEmpty ?? true
        }

        guard missingKeys.isEmpty else {
            throw XCTSkip("Live Supabase configuration missing: \(missingKeys.joined(separator: ", "))")
        }
    }

}
