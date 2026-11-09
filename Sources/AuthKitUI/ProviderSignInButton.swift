import SwiftUI
import AuthKit
import DesignTokensKit
import UIComponentsKit

/// A shared grid keeps provider marks and labels aligned across every row.
struct ProviderSignInButton: View {
    let provider: AuthProvider
    let isLoading: Bool
    var localizer: any AuthLocalizing = DefaultAuthLocalizer()
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var markSize = 22

    var body: some View {
        Button(action: action) {
            HStack(spacing: \.twelve) {
                mark.frame(width: markSize, height: markSize)
                    .accessibilityHidden(true)
                Text(continueWithText)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: markSize, height: markSize)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, \.sixteen)
            .padding(.vertical, \.twelve)
            .frame(minHeight: \.touchTargetSpacious)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: \.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: \.cardRadius)
                .strokeBorder(Color.primary.opacity(\.p0_18), lineWidth: StrokeWidth.one)
        }
        .opacity(isLoading ? \.p0_5 : \.p1_0)
        .disabled(isLoading)
        .accessibilityIdentifier(.authProvider(provider.rawValue))
    }

    private var continueWithText: String {
        let key = "auth.provider.continue_with.\(provider.rawValue)"
        let localized = localizer.string(key)
        if localized != key {
            return localized
        }
        let template = localizer.string("auth.provider.continue_with")
        if template.contains("%@") {
            return String(format: template, provider.displayName)
        }
        return "Continue with \(provider.displayName)"
    }

    private var foreground: Color {
        provider == .apple ? (colorScheme == .dark ? .black : .white) : .primary
    }
    private var background: Color {
        provider == .apple ? (colorScheme == .dark ? .white : .black) : Color.primary.opacity(0.035)
    }
    @ViewBuilder private var mark: some View {
        switch provider {
        case .apple:
            Image(systemName: \.appleLogo).resizable().scaledToFit()
        case .google:
            Image("Google", bundle: .module).resizable().scaledToFit()
        case .github:
            Image("GitHub", bundle: .module).resizable().scaledToFit()
        }
    }
}
