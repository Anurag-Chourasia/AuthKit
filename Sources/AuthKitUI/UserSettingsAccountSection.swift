import SwiftUI
import AuthKit
import DesignTokensKit
import LocalizationKit

/// User account credentials and destructive actions section for UserSettingsView.
public struct UserSettingsAccountSection: View {
    public let user: AuthUser?
    public let isLoading: Bool
    public let localizer: any AuthLocalizing
    public let onChangePassword: (() -> Void)?
    public let onSignOut: () -> Void
    public let onDeleteAccount: () -> Void

    public init(
        user: AuthUser?,
        isLoading: Bool = false,
        localizer: (any AuthLocalizing)? = nil,
        onChangePassword: (() -> Void)? = nil,
        onSignOut: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void
    ) {
        self.user = user
        self.isLoading = isLoading
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.onChangePassword = onChangePassword
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
    }

    public var body: some View {
        Section(localizer.string(\CommonStrings.authSectionSecurity)) {
            if let onChangePassword, user?.isPasswordUser == true {
                Button(action: onChangePassword) {
                    Label(localizer.string(\CommonStrings.authButtonChangePassword), \.lock)
                }
                .disabled(isLoading)
            }

            Button(role: .destructive, action: onSignOut) {
                Label(localizer.string(\CommonStrings.authButtonSignOut), \.rectanglePortraitAndArrowRight)
            }
            .disabled(isLoading)

            Button(role: .destructive, action: onDeleteAccount) {
                Label(localizer.string(\CommonStrings.authButtonDeleteAccount), \.trash)
            }
            .disabled(isLoading)
        }
    }
}
