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
            session: session,
            user: currentUser, isLoading: session.isLoading, localizer: localizer,
            aboutConfiguration: aboutConfiguration, currentAppScheme: currentAppScheme,
            onSaveProfile: { email, first, last, phone in
                Task { await session.updateProfile(email: email, firstName: first, lastName: last, phone: phone) }
            },
            onSendOTP: { try await session.sendPasswordResetOTP() },
            onChangePassword: { current, new, otp in
                try await session.changePassword(currentPassword: current, newPassword: new, otpCode: otp)
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
        session: SessionManager? = nil,
        user: AuthUser?, isLoading: Bool = false, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onSaveProfile: ((_ email: String?, _ first: String?, _ last: String?, _ phone: String?) -> Void)? = nil,
        onSendOTP: (() async throws -> Void)? = nil,
        onChangePassword: ((String, String, String) async throws -> Void)? = nil,
        onUpdatePassword: ((String) async throws -> Void)? = nil,
        onSignOut: @escaping () -> Void, onDeleteAccount: @escaping () -> Void, onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self.init(
            session: session,
            user: user, isLoading: isLoading, localizer: localizer,
            aboutConfiguration: aboutConfiguration, currentAppScheme: currentAppScheme,
            onSaveProfile: onSaveProfile, onSendOTP: onSendOTP, onChangePassword: onChangePassword,
            onUpdatePassword: onUpdatePassword, onSignOut: onSignOut,
            onDeleteAccount: onDeleteAccount, onDismiss: onDismiss,
            additionalContent: additionalContent, developerContent: { EmptyView() }
        )
    }

    public init(
        user: AuthUser?, isLoading: Bool = false, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onSaveProfile: ((_ first: String?, _ last: String?, _ phone: String?) -> Void)?,
        onUpdatePassword: ((String) async throws -> Void)? = nil,
        onSignOut: @escaping () -> Void, onDeleteAccount: @escaping () -> Void, onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self.init(
            user: user, isLoading: isLoading, localizer: localizer,
            aboutConfiguration: aboutConfiguration, currentAppScheme: currentAppScheme,
            onSaveProfile: onSaveProfile.map { cb in { cb($1, $2, $3) } },
            onSendOTP: nil, onChangePassword: nil, onUpdatePassword: onUpdatePassword,
            onSignOut: onSignOut, onDeleteAccount: onDeleteAccount, onDismiss: onDismiss,
            additionalContent: additionalContent
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
