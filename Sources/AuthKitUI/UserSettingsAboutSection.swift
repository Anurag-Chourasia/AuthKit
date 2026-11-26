import SwiftUI
import DesignTokensKit
import LocalizationKit

/// Informational application metadata and developer profile trigger for UserSettingsView.
public struct UserSettingsAboutSection: View {
    public let configuration: UserSettingsAboutConfiguration
    public let localizer: any AuthLocalizing

    public init(
        configuration: UserSettingsAboutConfiguration,
        localizer: (any AuthLocalizing)? = nil
    ) {
        self.configuration = configuration
        self.localizer = localizer ?? DefaultAuthLocalizer()
    }

    private var versionDisplay: String {
        "\(configuration.appName) \(configuration.version) (\(configuration.build))"
    }

    public var body: some View {
        Section(configuration.appName) {
            VStack(alignment: .leading, spacing: \.four) {
                Text(configuration.appName)
                    .font(\.headline)
                    .foregroundStyle(\.primary)
                Text(versionDisplay)
                    .font(\.subheadline)
                    .foregroundStyle(\.secondary)
            }
            .padding(.vertical, \.two)

            if let disclaimerText = configuration.disclaimerText {
                VStack(alignment: .leading, spacing: \.four) {
                    if let title = configuration.disclaimerTitle {
                        Text(LocalizedStringKey(title))
                            .font(\.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(\.secondary)
                    }
                    Text(LocalizedStringKey(disclaimerText))
                        .font(\.caption)
                        .foregroundStyle(\.secondary)
                }
                .padding(.vertical, \.two)
            }

            if let readmeURL = configuration.githubReadmeURL {
                Link(destination: readmeURL) {
                    Label(configuration.developerProfileTitle ?? configuration.appName, \.infoCircle)
                }
            } else if let onOpenDeveloperProfile = configuration.onOpenDeveloperProfile {
                Button(action: onOpenDeveloperProfile) {
                    Label(configuration.developerProfileTitle ?? configuration.appName, \.infoCircle)
                }
            }
        }
    }
}
