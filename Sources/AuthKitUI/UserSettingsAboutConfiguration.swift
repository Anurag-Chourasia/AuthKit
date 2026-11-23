import Foundation

/// Configuration metadata for the About section within UserSettingsView.
public struct UserSettingsAboutConfiguration: Sendable, Equatable {
    public let appName: String
    public let version: String
    public let build: String
    public let disclaimerTitle: String?
    public let disclaimerText: String?
    public let developerProfileTitle: String?
    public let onOpenDeveloperProfile: (@MainActor @Sendable () -> Void)?

    public init(
        appName: String,
        version: String,
        build: String,
        disclaimerTitle: String? = nil,
        disclaimerText: String? = nil,
        developerProfileTitle: String? = nil,
        onOpenDeveloperProfile: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.appName = appName
        self.version = version
        self.build = build
        self.disclaimerTitle = disclaimerTitle
        self.disclaimerText = disclaimerText
        self.developerProfileTitle = developerProfileTitle
        self.onOpenDeveloperProfile = onOpenDeveloperProfile
    }

    public static func == (lhs: UserSettingsAboutConfiguration, rhs: UserSettingsAboutConfiguration) -> Bool {
        lhs.appName == rhs.appName &&
        lhs.version == rhs.version &&
        lhs.build == rhs.build &&
        lhs.disclaimerTitle == rhs.disclaimerTitle &&
        lhs.disclaimerText == rhs.disclaimerText &&
        lhs.developerProfileTitle == rhs.developerProfileTitle
    }
}
