import Foundation
import AuthKit

/// SDK configuration stays inside the vendor adapter, outside the core and UI state machines.
public enum SupabaseBackendFactory {
    public static func make(projectURL: URL, publishableKey: String, callbackURL: URL,
                            storageKey: String) -> any AuthBackend {
        let manager = SupabaseManager(url: projectURL, publishableKey: publishableKey,
            authOptions: .init(redirectToURL: callbackURL, storageKey: storageKey))
        return SupabaseAuthBackend(manager: manager)
    }
}
