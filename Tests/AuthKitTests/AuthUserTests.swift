//
//  AuthUserTests.swift
//  AuthKit
//
//  Created by Anurag Chourasia on 31/10/26.
//


import Foundation
import XCTest
@testable import AuthKit

final class AuthUserTests: XCTestCase {

    func testUserInitialization() {
        // Given
        let id = UUID()
        let email = "test@example.com"

        // When
        let user = AuthUser(
            id: id,
            email: email
        )

        // Then
        XCTAssertEqual(user.id, id)
        XCTAssertEqual(user.email, email)
    }

    func testUsersWithSameDataAreEqual() {
        // Given
        let id = UUID()

        let first = AuthUser(
            id: id,
            email: "test@example.com"
        )

        let second = AuthUser(
            id: id,
            email: "test@example.com"
        )

        // Then
        XCTAssertEqual(first, second)
    }

    func testUserSupportsNilEmail() {
        let user = AuthUser(
            id: UUID(),
            email: nil
        )

        XCTAssertNil(user.email)
    }
}
