import SwiftUI
import DesignTokensKit

/// Secure text field with password visibility toggle and one-tap clear button.
public struct AuthSecureInputField: View {
    public let title: String
    @Binding public var text: String
    @State private var isRevealed: Bool = false

    public init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    public var body: some View {
        HStack(spacing: \.eight) {
            inputField
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(\.xmark).foregroundStyle(\.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
            }
            Button { isRevealed.toggle() } label: {
                Image(isRevealed ? \.eyeSlash : \.eye).foregroundStyle(\.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
        }
    }

    @ViewBuilder
    private var inputField: some View {
        if isRevealed {
            TextField(title, text: $text)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        } else {
            SecureField(title, text: $text)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        }
    }
}
