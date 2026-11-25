import SwiftUI
import DesignTokensKit

/// Floating confirmation banner presented when an auth action completes.
public struct AuthNoticeBanner: View {
    public let text: String
    public let onDismiss: (() -> Void)?

    public init(_ text: String, onDismiss: (() -> Void)? = nil) {
        self.text = text
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: \.eight) {
            Image(\.checkmarkCircleFill)
                .foregroundStyle(\.green)
            Text(text)
                .font(\.subheadline)
                .foregroundStyle(\.primary)
            if let onDismiss {
                Spacer()
                Button(action: onDismiss) {
                    Image(\.xmark)
                        .foregroundStyle(\.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, \.sixteen)
        .padding(.vertical, \.twelve)
        .background(\.surface)
        .cornerRadius(\.cardRadius)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            onDismiss?()
        }
    }
}
