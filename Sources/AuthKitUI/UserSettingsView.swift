import SwiftUI
import AuthKit
import DesignTokensKit
import LocalizationKit

/// Versatile user settings and account view.
public struct UserSettingsView<AdditionalContent: View>: View {
    public let user: AuthUser?
    public let isLoading: Bool
    public let localizer: any AuthLocalizing
    public let aboutConfiguration: UserSettingsAboutConfiguration?
    public let currentAppScheme: String?
    public let onSaveProfile: ((_ email: String?, _ first: String?, _ last: String?, _ phone: String?) -> Void)?
    public let onChangePassword: (() -> Void)?
    public let onSignOut: () -> Void
    public let onDeleteAccount: () -> Void
    private let additionalContent: () -> AdditionalContent

    public init(
        user: AuthUser?, isLoading: Bool = false, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onSaveProfile: ((_ email: String?, _ first: String?, _ last: String?, _ phone: String?) -> Void)? = nil,
        onChangePassword: (() -> Void)? = nil, onSignOut: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self.user = user; self.isLoading = isLoading
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.aboutConfiguration = aboutConfiguration; self.currentAppScheme = currentAppScheme
        self.onSaveProfile = onSaveProfile; self.onChangePassword = onChangePassword
        self.onSignOut = onSignOut; self.onDeleteAccount = onDeleteAccount
        self.additionalContent = additionalContent
    }

    public init(
        user: AuthUser?, isLoading: Bool = false, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onSaveProfile: ((_ first: String?, _ last: String?, _ phone: String?) -> Void)?,
        onChangePassword: (() -> Void)? = nil, onSignOut: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self.init(
            user: user, isLoading: isLoading, localizer: localizer,
            aboutConfiguration: aboutConfiguration, currentAppScheme: currentAppScheme,
            onSaveProfile: onSaveProfile.map { cb in { cb($1, $2, $3) } },
            onChangePassword: onChangePassword, onSignOut: onSignOut,
            onDeleteAccount: onDeleteAccount, additionalContent: additionalContent
        )
    }

    public var body: some View {
        Form {
            UserSettingsProfileSection(user: user, localizer: localizer, onSaveProfile: onSaveProfile)

            UserSettingsAccountSection(
                user: user, isLoading: isLoading, localizer: localizer,
                onChangePassword: onChangePassword, onSignOut: onSignOut, onDeleteAccount: onDeleteAccount
            )

            UserSettingsEcosystemAppsSection(localizer: localizer, currentAppScheme: currentAppScheme)

            if let aboutConfiguration {
                UserSettingsAboutSection(configuration: aboutConfiguration, localizer: localizer)
            }

            additionalContent()
        }
    }
}

extension UserSettingsView {
    public init(
        session: SessionManager, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onChangePassword: (() -> Void)? = nil, onSignedOut: (() -> Void)? = nil,
        onDeleteAccountRequested: (() -> Void)? = nil,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        let currentUser: AuthUser?
        if case .authenticated(let user) = session.state { currentUser = user } else { currentUser = nil }
        self.init(
            user: currentUser, isLoading: session.isLoading, localizer: localizer,
            aboutConfiguration: aboutConfiguration, currentAppScheme: currentAppScheme,
            onSaveProfile: { first, last, phone in
                Task { await session.updateProfile(firstName: first, lastName: last, phone: phone) }
            },
            onChangePassword: onChangePassword,
            onSignOut: { Task { await session.signOut(); onSignedOut?() } },
            onDeleteAccount: {
                if let onDeleteAccountRequested { onDeleteAccountRequested() } else {
                    Task { await session.deleteAccount(); onSignedOut?() }
                }
            },
            additionalContent: additionalContent
        )
    }
}
