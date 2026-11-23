import SwiftUI
import DesignTokensKit
import LocalizationKit

/// Modal sheet for authenticated user password change.
public struct ChangePasswordSheet: View {
    public let localizer: any AuthLocalizing
    public let onUpdatePassword: (String) async throws -> Void
    public let onDismiss: () -> Void

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    public init(
        localizer: (any AuthLocalizing)? = nil,
        onUpdatePassword: @escaping (String) async throws -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.onUpdatePassword = onUpdatePassword
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(localizer.string(\CommonStrings.authFieldNewPassword), text: $newPassword)
                    SecureField(localizer.string(\CommonStrings.authFieldConfirmPassword), text: $confirmPassword)
                } footer: {
                    Text(localizer.string(\CommonStrings.authInstructionPasswordRequirements))
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(\.caption)
                    }
                }

                Section {
                    Button(action: submitPassword) {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text(localizer.string(\CommonStrings.authButtonUpdatePassword))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || !isValid)
                }
            }
            .navigationTitle(localizer.string(\CommonStrings.authTitleChangePassword))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.string(\CommonStrings.cancel), action: onDismiss)
                }
            }
        }
    }

    private var isValid: Bool {
        newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func submitPassword() {
        guard isValid else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await onUpdatePassword(newPassword)
                isSubmitting = false
                onDismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
