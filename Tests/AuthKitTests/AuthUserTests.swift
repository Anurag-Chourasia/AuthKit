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

    func testUserSupportsNameAndPhone() {
        let user = AuthUser(
            id: UUID(),
            email: "john@example.com",
            firstName: "John",
            lastName: "Doe",
            phone: "+1234567890"
        )

        XCTAssertEqual(user.firstName, "John")
        XCTAssertEqual(user.lastName, "Doe")
        XCTAssertEqual(user.phone, "+1234567890")
        XCTAssertEqual(user.fullName, "John Doe")
    }

    func testFullNameFallsBackWhenOnlyOneNamePresent() {
        let onlyFirst = AuthUser(id: UUID(), email: nil, firstName: "Alice")
        XCTAssertEqual(onlyFirst.fullName, "Alice")

        let onlyLast = AuthUser(id: UUID(), email: nil, lastName: "Smith")
        XCTAssertEqual(onlyLast.fullName, "Smith")

        let emptyNames = AuthUser(id: UUID(), email: nil, firstName: "", lastName: "")
        XCTAssertNil(emptyNames.fullName)
    }
}
