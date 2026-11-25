import SwiftUI
import UIComponentsKit
import DesignTokensKit
import LocalizationKit

/// Reset password link trigger section for ChangePasswordSheet.
public struct ChangePasswordResetSection: View {
    public let localizer: any AuthLocalizing
    public let onSend: () async throws -> Void
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String?

    public init(localizer: any AuthLocalizing, onSend: @escaping () async throws -> Void) {
        self.localizer = localizer
        self.onSend = onSend
    }

    public var body: some View {
        Section {
            Button {
                isSending = true
                errorMessage = nil
                Task {
                    do {
                        try await onSend()
                        isSending = false
                        sent = true
                    } catch {
                        isSending = false
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack {
                    Label(localizer.string(\CommonStrings.authTitleResetPassword), \.envelope)
                    Spacer()
                    if isSending {
                        ProgressView().scaleEffect(\.p0_8)
                    }
                }
            }
            .disabled(isSending)
        } footer: {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(\.red).font(\.caption)
            } else if sent {
                Text(localizer.string(\CommonStrings.authNoticePasswordResetSent)).foregroundStyle(\.green)
            }
        }
    }
}
