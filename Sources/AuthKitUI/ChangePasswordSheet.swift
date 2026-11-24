import SwiftUI
import UIComponentsKit
import DesignTokensKit
import LocalizationKit

/// Modal sheet for authenticated user password change and email reset link dispatch.
public struct ChangePasswordSheet: View {
    public let localizer: any AuthLocalizing
    public let destination: String?
    public let onSendResetLink: (() async throws -> Void)?
    public let onChangePassword: ((String, String) async throws -> Void)?
    public let onUpdatePassword: ((String) async throws -> Void)?
    public let onDismiss: () -> Void

    @State private var currentPassword = ""; @State private var newPassword = ""
    @State private var confirmPassword = ""; @State private var isSubmitting = false
    @State private var isSendingReset = false; @State private var resetLinkSent = false
    @State private var errorMessage: String?

    public init(localizer: (any AuthLocalizing)? = nil, destination: String? = nil,
                onSendResetLink: (() async throws -> Void)? = nil,
                onChangePassword: ((String, String) async throws -> Void)? = nil,
                onUpdatePassword: ((String) async throws -> Void)? = nil,
                onDismiss: @escaping () -> Void) {
        self.localizer = localizer ?? DefaultAuthLocalizer(); self.destination = destination
        self.onSendResetLink = onSendResetLink; self.onChangePassword = onChangePassword
        self.onUpdatePassword = onUpdatePassword; self.onDismiss = onDismiss
    }

    public init(localizer: (any AuthLocalizing)? = nil, destination: String? = nil,
                onSendOTP: (() async throws -> Void)?,
                onChangePassword: ((String, String, String) async throws -> Void)?,
                onUpdatePassword: ((String) async throws -> Void)? = nil,
                onDismiss: @escaping () -> Void) {
        self.init(localizer: localizer, destination: destination, onSendResetLink: onSendOTP,
                  onChangePassword: { c, n in
            if let onChangePassword { try await onChangePassword(c, n, "") }
            else if let onUpdatePassword { try await onUpdatePassword(n) }
        }, onUpdatePassword: onUpdatePassword, onDismiss: onDismiss)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section { AuthSecureInputField(localizer.string(\CommonStrings.authFieldCurrentPassword), text: $currentPassword) }
                Section {
                    AuthSecureInputField(localizer.string(\CommonStrings.authFieldNewPassword), text: $newPassword)
                    AuthSecureInputField(localizer.string(\CommonStrings.authFieldConfirmPassword), text: $confirmPassword)
                } footer: { Text(localizer.string(\CommonStrings.authInstructionPasswordRequirements)) }
                if onSendResetLink != nil {
                    Section {
                        Button { sendResetLink() } label: {
                            HStack {
                                Label(localizer.string(\CommonStrings.authTitleResetPassword), \.envelope)
                                Spacer(); if isSendingReset { ProgressView().scaleEffect(\.p0_8) }
                            }
                        }.disabled(isSendingReset)
                    } footer: {
                        if resetLinkSent {
                            Text(localizer.string(\CommonStrings.authNoticePasswordResetSent)).foregroundStyle(\.green)
                        }
                    }
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(\.red).font(\.caption) } }
                Section { submitButton }
            }
            .scrollContentBackground(.hidden).background(\.background)
            .navigationTitle(localizer.string(\CommonStrings.authTitleChangePassword))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline).toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BrandPalette.current.background, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(localizer.string(\CommonStrings.cancel), action: onDismiss) }
            }
        }.background(\.background).applyModalSheetStyle()
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
        }.disabled(isSubmitting || !isValid)
    }

    private var isValid: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func sendResetLink() {
        guard let onSendResetLink else { return }
        isSendingReset = true; errorMessage = nil
        Task {
            do { try await onSendResetLink(); isSendingReset = false; resetLinkSent = true }
            catch { isSendingReset = false; errorMessage = error.localizedDescription }
        }
    }

    private func submitPassword() {
        guard isValid else { return }
        isSubmitting = true; errorMessage = nil
        Task {
            do {
                if let onChangePassword { try await onChangePassword(currentPassword, newPassword) }
                else if let onUpdatePassword { try await onUpdatePassword(newPassword) }
                isSubmitting = false; onDismiss()
            } catch { isSubmitting = false; errorMessage = error.localizedDescription }
        }
    }
}
