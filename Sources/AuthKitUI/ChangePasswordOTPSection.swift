import SwiftUI
import DesignTokensKit
import LocalizationKit

struct ChangePasswordOTPSection: View {
    let userEmail: String?
    let localizer: any AuthLocalizing
    let onSend: () async throws -> Void
    @Binding var otpCode: String
    @Binding var otpSent: Bool

    var body: some View {
        Section {
            if let userEmail, !userEmail.isEmpty {
                HStack {
                    Text(userEmail).font(\.subheadline).foregroundStyle(\.secondary)
                    Spacer()
                    Button(otpSent ? localizer.string(\CommonStrings.authInstructionResetEmailSent) : "Send OTP") {
                        Task { try? await onSend(); otpSent = true }
                    }
                    .font(\.footnote)
                }
            }
            HStack {
                TextField("Verification Code (OTP)", text: $otpCode)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                if !otpCode.isEmpty {
                    Button { otpCode = "" } label: { Image(\.xmark).foregroundStyle(\.secondary) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}
