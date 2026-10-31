import SwiftUI
import AuthKit
import DesignTokensKit

/// A shared grid keeps provider marks and labels aligned across every row.
struct ProviderSignInButton: View {
    let provider: AuthProvider
    let isLoading: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var markSize = 22

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.twelve) {
                mark.frame(width: markSize, height: markSize)
                    .accessibilityHidden(true)
                Text("Continue with \(provider.displayName)")
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: markSize, height: markSize)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.sixteen)
            .padding(.vertical, Spacing.twelve)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: CornerRadius.twelve))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.twelve)
                .strokeBorder(Color.primary.opacity(0.18), lineWidth: StrokeWidth.one)
        }
        .opacity(isLoading ? 0.5 : 1)
        .disabled(isLoading)
        .accessibilityIdentifier("auth.provider.\(provider.rawValue)")
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
            Image(systemName: "apple.logo").resizable().scaledToFit()
        case .google:
            Image("Google", bundle: .module).resizable().scaledToFit()
        case .github:
            Image("GitHub", bundle: .module).resizable().scaledToFit()
        }
    }
}
