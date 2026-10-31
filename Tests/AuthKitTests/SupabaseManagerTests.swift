//
//  SupabaseManagerTests.swift
//  AuthKit
//
//  Created by Anurag Chourasia on 31/10/26.
//

import Foundation
import XCTest
@testable import AuthKit

final class SupabaseManagerTests: XCTestCase {

    func testSupabaseClientInitialization() {
        // Given
        let url = URL(
            string: "https://example.supabase.co"
        )!

        let key = "sb_publishable_test_key"

        // When
        let manager = SupabaseManager(
            url: url,
            publishableKey: key
        )

        // Then
        let headers = manager.client.headers

        let apiKey = headers.first {
            $0.key.lowercased() == "apikey"
        }?.value

        XCTAssertEqual(apiKey, key)
    }

    func testAuthorizationHeader() {
        // Given
        let url = URL(
            string: "https://example.supabase.co"
        )!

        let key = "sb_publishable_test_key"

        // When
        let manager = SupabaseManager(
            url: url,
            publishableKey: key
        )

        // Then
        let authorization = manager.client.headers.first {
            $0.key.lowercased() == "authorization"
        }?.value

        XCTAssertEqual(
            authorization,
            "Bearer \(key)"
        )
    }
}
