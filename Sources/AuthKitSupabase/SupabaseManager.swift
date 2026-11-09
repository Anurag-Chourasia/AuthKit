//
//  SupabaseManager.swift
//  AuthKit
//
//  Created by Anurag Chourasia on 31/10/26.
//

import Foundation
import AuthKit
import Supabase

public final class SupabaseManager: Sendable {

    public let client: SupabaseClient

    public init(
        url: URL,
        publishableKey: String,
        authOptions: SupabaseClientOptions.AuthOptions = .init(),
        globalOptions: SupabaseClientOptions.GlobalOptions = .init()
    ) {
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: publishableKey,
            options: SupabaseClientOptions(auth: authOptions, global: globalOptions)
        )
    }
}
