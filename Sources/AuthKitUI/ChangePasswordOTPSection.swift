import SwiftUI
import DesignTokensKit
import LocalizationKit

struct ChangePasswordOTPSection: View {
    let destination: String?
    let localizer: any AuthLocalizing
    let onSend: () async throws -> Void
    @Binding var otpCode: String
    @Binding var otpSent: Bool
    @State private var isSending = false

    var body: some View {
        Section {
            if let destination, !destination.isEmpty {
                HStack {
                    Text(destination).font(\.subheadline).foregroundStyle(\.secondary)
                    Spacer()
                    if isSending {
                        ProgressView().scaleEffect(\.p0_8)
                    } else {
                        Button(otpButtonTitle) { sendCode() }
                            .font(\.footnote)
                    }
                }
            }
            HStack {
                TextField(localizer.string(\CommonStrings.authFieldOtpCode), text: $otpCode)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                if !otpCode.isEmpty {
                    Button { otpCode = "" } label: { Image(\.xmark).foregroundStyle(\.secondary) }
                        .buttonStyle(.plain)
                }
            }
        } footer: {
            if otpSent {
                Text(localizer.string(\CommonStrings.authStatusOtpSent))
            }
        }
    }

    private var otpButtonTitle: String {
        otpSent
            ? localizer.string(\CommonStrings.authButtonResendOtp)
            : localizer.string(\CommonStrings.authButtonSendOtp)
    }

    private func sendCode() {
        isSending = true
        Task {
            try? await onSend()
            isSending = false
            otpSent = true
        }
    }
}
