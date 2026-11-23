import SwiftUI
import AuthKit
import LocalizationKit

@MainActor
extension UserSettingsSheet {
    public init(
        session: SessionManager, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() },
        @ViewBuilder developerContent: @escaping () -> DeveloperContent
    ) {
        let currentUser: AuthUser?
        if case .authenticated(let user) = session.state { currentUser = user } else { currentUser = nil }
        self.init(
            user: currentUser, isLoading: session.isLoading, localizer: localizer,
            aboutConfiguration: aboutConfiguration, currentAppScheme: currentAppScheme,
            onSaveProfile: { first, last, phone in
                Task { await session.updateProfile(firstName: first, lastName: last, phone: phone) }
            },
            onUpdatePassword: { await session.updatePassword($0) },
            onSignOut: { Task { await session.signOut(); onDismiss() } },
            onDeleteAccount: { Task { await session.deleteAccount(); onDismiss() } },
            onDismiss: onDismiss, additionalContent: additionalContent, developerContent: developerContent
        )
    }
}

@MainActor
extension UserSettingsSheet where DeveloperContent == EmptyView {
    public init(
        user: AuthUser?, isLoading: Bool = false, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onSaveProfile: ((_ first: String?, _ last: String?, _ phone: String?) -> Void)? = nil,
        onUpdatePassword: ((String) async throws -> Void)? = nil,
        onSignOut: @escaping () -> Void, onDeleteAccount: @escaping () -> Void, onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self.init(
            user: user, isLoading: isLoading, localizer: localizer,
            aboutConfiguration: aboutConfiguration, currentAppScheme: currentAppScheme,
            onSaveProfile: onSaveProfile, onUpdatePassword: onUpdatePassword,
            onSignOut: onSignOut, onDeleteAccount: onDeleteAccount, onDismiss: onDismiss,
            additionalContent: additionalContent, developerContent: { EmptyView() }
        )
    }

    public init(
        session: SessionManager, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self.init(
            session: session, localizer: localizer,
            aboutConfiguration: aboutConfiguration, currentAppScheme: currentAppScheme,
            onDismiss: onDismiss, additionalContent: additionalContent, developerContent: { EmptyView() }
        )
    }
}
