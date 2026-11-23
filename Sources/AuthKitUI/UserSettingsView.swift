import SwiftUI
import AuthKit
import DesignTokensKit
import LocalizationKit

/// Versatile user settings and account view.
/// Embeds into NavigationStack, sheet, or custom parent layouts.
public struct UserSettingsView<AdditionalContent: View>: View {
    public let user: AuthUser?
    public let isLoading: Bool
    public let localizer: any AuthLocalizing
    public let aboutConfiguration: UserSettingsAboutConfiguration?
    public let onSignOut: () -> Void
    public let onDeleteAccount: () -> Void
    private let additionalContent: () -> AdditionalContent

    public init(
        user: AuthUser?,
        isLoading: Bool = false,
        localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil,
        onSignOut: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self.user = user
        self.isLoading = isLoading
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.aboutConfiguration = aboutConfiguration
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
        self.additionalContent = additionalContent
    }

    public var body: some View {
        Form {
            UserSettingsAccountSection(
                user: user,
                isLoading: isLoading,
                localizer: localizer,
                onSignOut: onSignOut,
                onDeleteAccount: onDeleteAccount
            )

            if let aboutConfiguration {
                UserSettingsAboutSection(
                    configuration: aboutConfiguration,
                    localizer: localizer
                )
            }

            additionalContent()
        }
    }
}

extension UserSettingsView {
    public init(
        session: SessionManager,
        localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil,
        onSignedOut: (() -> Void)? = nil,
        onDeleteAccountRequested: (() -> Void)? = nil,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        let currentUser: AuthUser?
        if case .authenticated(let user) = session.state {
            currentUser = user
        } else {
            currentUser = nil
        }
        self.init(
            user: currentUser,
            isLoading: session.isLoading,
            localizer: localizer,
            aboutConfiguration: aboutConfiguration,
            onSignOut: {
                Task {
                    await session.signOut()
                    onSignedOut?()
                }
            },
            onDeleteAccount: {
                if let onDeleteAccountRequested {
                    onDeleteAccountRequested()
                } else {
                    Task {
                        await session.deleteAccount()
                        onSignedOut?()
                    }
                }
            },
            additionalContent: additionalContent
        )
    }
}
