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
    public let onSignOut: () -> Void
    public let onDeleteAccount: () -> Void
    public let onDismiss: () -> Void
    private let additionalContent: () -> AdditionalContent
    private let developerContent: (() -> DeveloperContent)?

    @State private var showingDeleteConfirmation = false
    @State private var showingDeveloperProfile = false

    public init(
        user: AuthUser?, isLoading: Bool = false, localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil,
        onSignOut: @escaping () -> Void, onDeleteAccount: @escaping () -> Void, onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() },
        @ViewBuilder developerContent: @escaping () -> DeveloperContent
    ) {
        self.user = user; self.isLoading = isLoading
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.aboutConfiguration = aboutConfiguration
        self.onSignOut = onSignOut; self.onDeleteAccount = onDeleteAccount; self.onDismiss = onDismiss
        self.additionalContent = additionalContent; self.developerContent = developerContent
    }

    public var body: some View {
        NavigationStack {
            UserSettingsView(
                user: user, isLoading: isLoading, localizer: localizer,
                aboutConfiguration: resolvedAboutConfiguration, onSignOut: onSignOut,
                onDeleteAccount: { showingDeleteConfirmation = true }, additionalContent: additionalContent
            )
            .navigationTitle(localizer.string(\CommonStrings.accountTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .confirmationDialog(
                localizer.string(\CommonStrings.accountDeleteConfirmationTitle),
                isPresented: $showingDeleteConfirmation, titleVisibility: .visible
            ) {
                Button(localizer.string(\CommonStrings.accountDeleteConfirmationAction), role: .destructive) {
                    onDeleteAccount()
                }
                Button(localizer.string(\CommonStrings.cancel), role: .cancel) {}
            } message: {
                Text(localizer.string(\CommonStrings.accountDeleteConfirmationMessage))
            }
            .sheet(isPresented: $showingDeveloperProfile) {
                if let developerContent { developerContent() }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            Button(localizer.string(\CommonStrings.done), action: onDismiss)
        }
        #else
        ToolbarItem(placement: .automatic) {
            Button(localizer.string(\CommonStrings.done), action: onDismiss)
        }
        #endif
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
