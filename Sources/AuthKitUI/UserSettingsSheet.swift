import SwiftUI
import AuthKit
import DesignTokensKit
import LocalizationKit

/// Modal sheet container wrapping UserSettingsView with navigation and dismiss controls.
@MainActor
public struct UserSettingsSheet<AdditionalContent: View, DeveloperContent: View>: View {
    public let user: AuthUser?
    public let isLoading: Bool
    public let localizer: any AuthLocalizing
    public let aboutConfiguration: UserSettingsAboutConfiguration?
    public let currentAppScheme: String?
    public let onSaveProfile: ((_ email: String?, _ first: String?, _ last: String?, _ phone: String?) -> Void)?
    public let onUpdatePassword: ((String) async throws -> Void)?
    public let onSignOut: () -> Void
    public let onDeleteAccount: () -> Void
    public let onDismiss: () -> Void
    private let additionalContent: () -> AdditionalContent
    private let developerContent: (() -> DeveloperContent)?

    @State private var showingDeleteConfirmation = false
    @State private var showingDeveloperProfile = false
    @State private var showingChangePassword = false

    public init(
        user: AuthUser?, isLoading: Bool = false, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onSaveProfile: ((_ email: String?, _ first: String?, _ last: String?, _ phone: String?) -> Void)? = nil,
        onUpdatePassword: ((String) async throws -> Void)? = nil,
        onSignOut: @escaping () -> Void, onDeleteAccount: @escaping () -> Void, onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() },
        @ViewBuilder developerContent: @escaping () -> DeveloperContent
    ) {
        self.user = user; self.isLoading = isLoading
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.aboutConfiguration = aboutConfiguration; self.currentAppScheme = currentAppScheme
        self.onSaveProfile = onSaveProfile; self.onUpdatePassword = onUpdatePassword
        self.onSignOut = onSignOut; self.onDeleteAccount = onDeleteAccount; self.onDismiss = onDismiss
        self.additionalContent = additionalContent; self.developerContent = developerContent
    }

    public var body: some View {
        NavigationStack {
            UserSettingsView(
                user: user, isLoading: isLoading, localizer: localizer,
                aboutConfiguration: resolvedAboutConfiguration, currentAppScheme: currentAppScheme,
                onSaveProfile: onSaveProfile,
                onChangePassword: onUpdatePassword != nil ? { showingChangePassword = true } : nil,
                onSignOut: onSignOut, onDeleteAccount: { showingDeleteConfirmation = true },
                additionalContent: additionalContent
            )
            .navigationTitle(localizer.string(\CommonStrings.accountTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BrandPalette.current.background, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizer.string(\CommonStrings.done), action: onDismiss)
                }
            }
            .confirmationDialog(
                localizer.string(\CommonStrings.accountDeleteConfirmationTitle),
                isPresented: $showingDeleteConfirmation, titleVisibility: .visible
            ) {
                Button(localizer.string(\CommonStrings.accountDeleteConfirmationAction),
                       role: .destructive, action: onDeleteAccount)
                Button(localizer.string(\CommonStrings.cancel), role: .cancel) {}
            } message: { Text(localizer.string(\CommonStrings.accountDeleteConfirmationMessage)) }
            .sheet(isPresented: $showingChangePassword) {
                if let onUpdatePassword {
                    ChangePasswordSheet(
                        localizer: localizer, userEmail: user?.email, onUpdatePassword: onUpdatePassword,
                        onDismiss: { showingChangePassword = false }
                    )
                }
            }
            .sheet(isPresented: $showingDeveloperProfile) {
                if let developerContent { developerContent() }
            }
        }
        .background(\.background)
    }

    private var resolvedAboutConfiguration: UserSettingsAboutConfiguration? {
        guard let config = aboutConfiguration, developerContent != nil else { return aboutConfiguration }
        return UserSettingsAboutConfiguration(
            appName: config.appName, version: config.version, build: config.build,
            disclaimerTitle: config.disclaimerTitle, disclaimerText: config.disclaimerText,
            developerProfileTitle: config.developerProfileTitle,
            onOpenDeveloperProfile: { [self] in showingDeveloperProfile = true }
        )
    }
}
