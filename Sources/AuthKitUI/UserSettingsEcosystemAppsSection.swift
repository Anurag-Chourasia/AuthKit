import SwiftUI
import DesignTokensKit
import LocalizationKit

/// Ecosystem app descriptor for deep linking.
public struct EcosystemAppItem: Identifiable, @unchecked Sendable {
    public let id: String
    public let scheme: String
    public let nameKey: KeyPath<CommonStrings, String>
    public let subtitleKey: KeyPath<CommonStrings, String>
    public let symbol: KeyPath<SymbolTheme, AppSymbol>
    public let iconColor: KeyPath<ColorTheme, Color>

    public init(
        id: String, scheme: String, nameKey: KeyPath<CommonStrings, String>,
        subtitleKey: KeyPath<CommonStrings, String>, symbol: KeyPath<SymbolTheme, AppSymbol>,
        iconColor: KeyPath<ColorTheme, Color> = \.action
    ) {
        self.id = id; self.scheme = scheme; self.nameKey = nameKey
        self.subtitleKey = subtitleKey; self.symbol = symbol; self.iconColor = iconColor
    }

    public var url: URL {
        URL(string: "\(scheme)://") ?? URL(fileURLWithPath: "/")
    }
}

/// Ecosystem applications section with deep links to launch peer apps.
public struct UserSettingsEcosystemAppsSection: View {
    public let localizer: any AuthLocalizing
    public let currentAppScheme: String?
    @Environment(\.openURL) private var openURL

    public static let defaultApps: [EcosystemAppItem] = [
        EcosystemAppItem(
            id: "motivationdaily", scheme: "motivationdaily",
            nameKey: \CommonStrings.authAppsMotivationDaily,
            subtitleKey: \CommonStrings.authAppsMotivationDailySubtitle,
            symbol: \.quoteOpening, iconColor: \.orange
        ),
        EcosystemAppItem(
            id: "showbook", scheme: "showbook",
            nameKey: \CommonStrings.authAppsShowbook,
            subtitleKey: \CommonStrings.authAppsShowbookSubtitle,
            symbol: \.bookClosed, iconColor: \.blue
        ),
        EcosystemAppItem(
            id: "mytv", scheme: "mytv",
            nameKey: \CommonStrings.authAppsMytv,
            subtitleKey: \CommonStrings.authAppsMytvSubtitle,
            symbol: \.tv, iconColor: \.turquoise
        )
    ]

    public init(
        localizer: (any AuthLocalizing)? = nil,
        currentAppScheme: String? = nil
    ) {
        self.localizer = localizer ?? DefaultAuthLocalizer()
        self.currentAppScheme = currentAppScheme
    }

    private var filteredApps: [EcosystemAppItem] {
        guard let current = currentAppScheme?.lowercased() else { return Self.defaultApps }
        return Self.defaultApps.filter { !$0.scheme.lowercased().contains(current) }
    }

    public var body: some View {
        Section(localizer.string(\CommonStrings.authSectionEcosystemApps)) {
            ForEach(filteredApps) { app in
                Button(action: { openURL(app.url) }) {
                    HStack(spacing: \.twelve) {
                        Image(app.symbol)
                            .font(\.title3)
                            .frame(width: \.p32, height: \.p32)
                            .foregroundStyle(app.iconColor)

                        VStack(alignment: .leading, spacing: \.two) {
                            Text(localizer.string(app.nameKey))
                                .font(\.body)
                                .fontWeight(.medium)
                                .foregroundStyle(\.primary)
                            Text(localizer.string(app.subtitleKey))
                                .font(\.caption)
                                .foregroundStyle(\.secondary)
                        }

                        Spacer()

                        Image(\.arrowUpForwardApp)
                            .font(\.footnote)
                            .foregroundStyle(\.secondary)
                    }
                    .padding(.vertical, \.two)
                }
            }
        }
    }
}
