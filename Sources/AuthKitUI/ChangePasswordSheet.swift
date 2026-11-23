import SwiftUI
import DesignTokensKit
import LocalizationKit

/// Modal sheet for authenticated user password change with current password, eye toggle, and OTP verification.
public struct ChangePasswordSheet: View {
    public let localizer: any AuthLocalizing
    public let destination: String?
    public let onSendOTP: (() async throws -> Void)?
    public let onChangePassword: ((String, String, String) async throws -> Void)?
    public let onUpdatePassword: ((String) async throws -> Void)?
    public let onDismiss: () -> Void

    @State private var currentPassword = ""; @State private var newPassword = ""
    @State private var confirmPassword = ""; @State private var otpCode = ""
    @State private var otpSent = false; @State private var isSubmitting = false
    @State private var errorMessage: String?

    public init(localizer: (any AuthLocalizing)? = nil, destination: String? = nil,
                onSendOTP: (() async throws -> Void)? = nil,
                onChangePassword: ((String, String, String) async throws -> Void)? = nil,
                onUpdatePassword: ((String) async throws -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.localizer = localizer ?? DefaultAuthLocalizer(); self.destination = destination
        self.onSendOTP = onSendOTP; self.onChangePassword = onChangePassword
        self.onUpdatePassword = onUpdatePassword; self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    AuthSecureInputField(localizer.string(\CommonStrings.authFieldCurrentPassword), text: $currentPassword)
                }
                Section {
                    AuthSecureInputField(localizer.string(\CommonStrings.authFieldNewPassword), text: $newPassword)
                    AuthSecureInputField(localizer.string(\CommonStrings.authFieldConfirmPassword), text: $confirmPassword)
                } footer: { Text(localizer.string(\CommonStrings.authInstructionPasswordRequirements)) }
                if let onSendOTP {
                    ChangePasswordOTPSection(
                        destination: destination, localizer: localizer, onSend: onSendOTP,
                        otpCode: $otpCode, otpSent: $otpSent
                    )
                }
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
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BrandPalette.current.background, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.string(\CommonStrings.cancel), action: onDismiss)
                }
            }
        }
        .background(\.background)
        .applyModalSheetStyle()
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
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
            && (onSendOTP == nil || !otpCode.isEmpty)
    }

    private func submitPassword() {
        guard isValid else { return }
        isSubmitting = true; errorMessage = nil
        Task {
            do {
                if let onChangePassword {
                    try await onChangePassword(currentPassword, newPassword, otpCode)
                } else if let onUpdatePassword { try await onUpdatePassword(newPassword) }
                isSubmitting = false; onDismiss()
            } catch { isSubmitting = false; errorMessage = error.localizedDescription }
        }
    }
}
