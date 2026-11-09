import Foundation
import LocalizationKit

/// Protocol for localizing authentication and account surfaces in AuthKitUI.
/// Compatible with `LocalizationProviding` from `LocalizationKit`.
public protocol AuthLocalizing: Sendable {
    func string(_ key: String) -> String
    var isRightToLeft: Bool { get }
}

public extension AuthLocalizing {
    var isRightToLeft: Bool { false }

    /// KeyPath-based string lookup via LocalizationKit.
    func string(_ keyPath: KeyPath<CommonStrings, String>, context: CommonStrings = .shared) -> String {
        context[keyPath: keyPath]
    }
}

/// Default built-in localizer backed by `LocalizationKit`.
public struct DefaultAuthLocalizer: AuthLocalizing {
    public let isRightToLeft: Bool
    private let customStrings: [String: String]
    private let provider: any LocalizationProviding

    public init(
        isRightToLeft: Bool = false,
        customStrings: [String: String] = [:],
        provider: (any LocalizationProviding)? = nil
    ) {
        let activeProvider = provider ?? LocalizationController.shared
        self.isRightToLeft = isRightToLeft || activeProvider.isRightToLeft
        self.customStrings = customStrings
        self.provider = activeProvider
    }

    public func string(_ key: String) -> String {
        if let custom = customStrings[key] {
            return custom
        }
        let localized = provider.string(key)
        if localized != key {
            return localized
        }
        return key
    }
}
