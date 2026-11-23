import SwiftUI
import DesignTokensKit
import LocalizationKit

/// Modal sheet for authenticated user password change with eye toggle, clear button, and OTP verification.
public struct ChangePasswordSheet: View {
    public let localizer: any AuthLocalizing
    public let userEmail: String?
    public let onSendOTP: (() async throws -> Void)?
    public let onUpdatePassword: (String) async throws -> Void
    public let onDismiss: () -> Void

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var otpCode = ""
    @State private var otpSent = false
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    public init(
        localizer: (any AuthLocalizing)? = nil, userEmail: String? = nil,
        onSendOTP: (() async throws -> Void)? = nil,
        onUpdatePassword: @escaping (String) async throws -> Void, onDismiss: @escaping () -> Void
    ) {
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.userEmail = userEmail
        self.onSendOTP = onSendOTP
        self.onUpdatePassword = onUpdatePassword
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let onSendOTP {
                    ChangePasswordOTPSection(
                        userEmail: userEmail, localizer: localizer, onSend: onSendOTP,
                        otpCode: $otpCode, otpSent: $otpSent
                    )
                }
                Section {
                    AuthSecureInputField(localizer.string(\CommonStrings.authFieldNewPassword), text: $newPassword)
                    AuthSecureInputField(localizer.string(\CommonStrings.authFieldConfirmPassword), text: $confirmPassword)
                } footer: { Text(localizer.string(\CommonStrings.authInstructionPasswordRequirements)) }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(\.red).font(\.caption) }
                }
                Section { submitButton }
            }
            .scrollContentBackground(.hidden)
            .background(\.background)
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

    private var submitButton: some View {
        Button(action: submitPassword) {
            HStack {
                Spacer()
                if isSubmitting { ProgressView() } else {
                    Text(localizer.string(\CommonStrings.authButtonUpdatePassword)).fontWeight(.semibold)
                }
                Spacer()
            }
        }
        .disabled(isSubmitting || !isValid)
    }

    private var isValid: Bool {
        newPassword.count >= 8 && newPassword == confirmPassword && (onSendOTP == nil || !otpCode.isEmpty)
    }

    private func submitPassword() {
        guard isValid else { return }
        isSubmitting = true; errorMessage = nil
        Task {
            do {
                try await onUpdatePassword(newPassword)
                isSubmitting = false; onDismiss()
            } catch {
                isSubmitting = false; errorMessage = error.localizedDescription
            }
        }
    }
}
