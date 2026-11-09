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

    public init(
        id: UUID,
        email: String?
    ) {
        self.id = id
        self.email = email
    }
}
