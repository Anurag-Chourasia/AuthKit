import SwiftUI
import AuthKit
import UIComponentsKit
import DesignTokensKit
import LocalizationKit

/// Modal sheet container wrapping UserSettingsView with navigation and dismiss controls.
@MainActor
public struct UserSettingsSheet<AdditionalContent: View, DeveloperContent: View>: View {
    public let user: AuthUser?; public let isLoading: Bool
    public let localizer: any AuthLocalizing; public let currentAppScheme: String?
    public let aboutConfiguration: UserSettingsAboutConfiguration?
    public let onSaveProfile: ((_ email: String?, _ first: String?, _ last: String?, _ phone: String?) -> Void)?
    public let onSendOTP: (() async throws -> Void)?
    public let onChangePassword: ((String, String, String) async throws -> Void)?
    public let onUpdatePassword: ((String) async throws -> Void)?
    public let onSignOut: () -> Void; public let onDeleteAccount: () -> Void; public let onDismiss: () -> Void
    private let additionalContent: () -> AdditionalContent
    private let developerContent: (() -> DeveloperContent)?

    @State private var showingDeleteConfirmation = false; @State private var showingDeveloperProfile = false
    @State private var showingChangePassword = false

    public init(
        user: AuthUser?, isLoading: Bool = false, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil, currentAppScheme: String? = nil,
        onSaveProfile: ((_ email: String?, _ first: String?, _ last: String?, _ phone: String?) -> Void)? = nil,
        onSendOTP: (() async throws -> Void)? = nil,
        onChangePassword: ((String, String, String) async throws -> Void)? = nil,
        onUpdatePassword: ((String) async throws -> Void)? = nil,
        onSignOut: @escaping () -> Void, onDeleteAccount: @escaping () -> Void, onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() },
        @ViewBuilder developerContent: @escaping () -> DeveloperContent
    ) {
        self.user = user; self.isLoading = isLoading; self.localizer = localizer ?? DefaultAuthLocalizer()
        self.aboutConfiguration = aboutConfiguration; self.currentAppScheme = currentAppScheme
        self.onSaveProfile = onSaveProfile; self.onSendOTP = onSendOTP
        self.onChangePassword = onChangePassword; self.onUpdatePassword = onUpdatePassword
        self.onSignOut = onSignOut; self.onDeleteAccount = onDeleteAccount; self.onDismiss = onDismiss
        self.additionalContent = additionalContent; self.developerContent = developerContent
    }

    public var body: some View {
        NavigationStack {
            UserSettingsView(
                user: user, isLoading: isLoading, localizer: localizer,
                aboutConfiguration: resolvedAboutConfiguration, currentAppScheme: currentAppScheme,
                onSaveProfile: onSaveProfile, onChangePassword: hasPasswordAction ? { showingChangePassword = true } : nil,
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
                Button(localizer.string(\CommonStrings.accountDeleteConfirmationAction), role: .destructive,
                       action: onDeleteAccount)
                Button(localizer.string(\CommonStrings.cancel), role: .cancel) {}
            } message: { Text(localizer.string(\CommonStrings.accountDeleteConfirmationMessage)) }
            .sheet(isPresented: $showingChangePassword) {
                if hasPasswordAction {
                    ChangePasswordSheet(
                        localizer: localizer, destination: user?.email ?? user?.phone,
                        onSendOTP: onSendOTP, onChangePassword: onChangePassword,
                        onUpdatePassword: onUpdatePassword, onDismiss: { showingChangePassword = false }
                    )
                }
            }
            .sheet(isPresented: $showingDeveloperProfile) {
                if let developerContent {
                    developerContent()
                        .applyModalSheetStyle()
                }
            }
        }
        .background(\.background)
        .applyModalSheetStyle()
    }

    private var hasPasswordAction: Bool { onChangePassword != nil || onUpdatePassword != nil }

    private var resolvedAboutConfiguration: UserSettingsAboutConfiguration? {
        guard let c = aboutConfiguration, developerContent != nil else { return aboutConfiguration }
        return UserSettingsAboutConfiguration(
            appName: c.appName, version: c.version, build: c.build,
            disclaimerTitle: c.disclaimerTitle, disclaimerText: c.disclaimerText,
            onOpenDeveloperProfile: { showingDeveloperProfile = true }
        )
    }
}
