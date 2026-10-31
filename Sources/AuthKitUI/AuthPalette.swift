import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Apps own brand values. Shared kits own roles, scales and component behaviour.
public struct AuthPalette: Sendable {
    public var action: Color
    public var onAction: Color
    public var background: Color
    public var foreground: Color

    public init(action: Color, onAction: Color = .white,
                background: Color = .clear, foreground: Color = .primary) {
        self.action = action
        self.onAction = onAction
        self.background = background
        self.foreground = foreground
    }

    /// Resolve host-owned semantic assets; absent roles fall back individually.
    public static func appAssets(in bundle: Bundle = .main, fallback: AuthPalette) -> AuthPalette {
        func color(_ name: String, fallback: Color) -> Color {
            #if canImport(UIKit)
            guard UIColor(named: name, in: bundle, compatibleWith: nil) != nil else { return fallback }
            #elseif canImport(AppKit)
            guard NSColor(named: NSColor.Name(name), bundle: bundle) != nil else { return fallback }
            #endif
            return Color(name, bundle: bundle)
        }
        return .init(action: color("AuthAction", fallback: fallback.action),
                     onAction: color("AuthOnAction", fallback: fallback.onAction),
                     background: color("AuthBackground", fallback: fallback.background),
                     foreground: color("AuthForeground", fallback: fallback.foreground))
    }

    public static func projectDefault(for brand: AuthBrand) -> AuthPalette {
        let prefix: String
        switch brand {
        case .myTV: prefix = "MyTV"
        case .showBook: prefix = "ShowBook"
        case .motivationDaily: prefix = "MotivationDaily"
        }
        return .init(action: Color(prefix + "AuthAction", bundle: .module),
                     onAction: Color(prefix + "AuthOnAction", bundle: .module),
                     background: Color(prefix + "AuthBackground", bundle: .module),
                     foreground: Color(prefix + "AuthForeground", bundle: .module))
    }
}
