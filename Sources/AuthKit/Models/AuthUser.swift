//
//  AuthUser.swift
//  AuthKit
//
//  Created by Anurag Chourasia on 31/10/26.
//

import Foundation

public struct AuthUser: Identifiable, Equatable, Sendable {

    public let id: UUID
    public let email: String?
    public let firstName: String?
    public let lastName: String?
    public let phone: String?
    public let provider: String?

    public init(
        id: UUID,
        email: String?,
        firstName: String? = nil,
        lastName: String? = nil,
        phone: String? = nil,
        provider: String? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.provider = provider
    }

    public var fullName: String? {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    public var isPasswordUser: Bool {
        provider == nil || provider == "email"
    }
}
