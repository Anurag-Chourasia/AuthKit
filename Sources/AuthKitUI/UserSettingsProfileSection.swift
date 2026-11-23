import SwiftUI
import AuthKit
import DesignTokensKit
import LocalizationKit

/// Profile information section for UserSettingsView displaying name, email, and phone.
public struct UserSettingsProfileSection: View {
    public let user: AuthUser?
    public let localizer: any AuthLocalizing
    public let onSaveProfile: ((_ firstName: String?, _ lastName: String?, _ phone: String?) -> Void)?

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var hasEdits: Bool = false

    public init(
        user: AuthUser?, localizer: (any AuthLocalizing)? = nil,
        onSaveProfile: ((_ firstName: String?, _ lastName: String?, _ phone: String?) -> Void)? = nil
    ) {
        self.user = user; self.localizer = localizer ?? DefaultAuthLocalizer(); self.onSaveProfile = onSaveProfile
        _firstName = State(initialValue: user?.firstName ?? "")
        _lastName = State(initialValue: user?.lastName ?? "")
        _phone = State(initialValue: user?.phone ?? "")
    }

    public var body: some View {
        Section(localizer.string(\CommonStrings.authSectionProfile)) {
            HStack(spacing: \.twelve) {
                Image(\.personCropCircle).foregroundStyle(\.secondary)
                VStack(alignment: .leading, spacing: \.two) {
                    Text(displayName).font(\.headline).foregroundStyle(user != nil ? \.primary : \.secondary)
                    Text(user?.email ?? localizer.string(\CommonStrings.accountTitle))
                        .font(\.subheadline).foregroundStyle(\.secondary)
                }
            }
            .padding(.vertical, \.two)

            HStack {
                Label(localizer.string(\CommonStrings.authFieldFirstName), \.person).foregroundStyle(\.secondary)
                Spacer()
                TextField(localizer.string(\CommonStrings.authFieldFirstName), text: $firstName)
                    .multilineTextAlignment(.trailing).onChange(of: firstName) { _ in hasEdits = true }
            }

            HStack {
                Label(localizer.string(\CommonStrings.authFieldLastName), \.person).foregroundStyle(\.secondary)
                Spacer()
                TextField(localizer.string(\CommonStrings.authFieldLastName), text: $lastName)
                    .multilineTextAlignment(.trailing).onChange(of: lastName) { _ in hasEdits = true }
            }

            HStack {
                Label(localizer.string(\CommonStrings.authFieldEmail), \.envelope).foregroundStyle(\.secondary)
                Spacer()
                Text(user?.email ?? "—").foregroundStyle(\.secondary)
            }

            phoneRow

            if hasEdits, onSaveProfile != nil {
                Button(action: saveChanges) {
                    Label(localizer.string(\CommonStrings.authButtonSaveProfile), \.checkmark)
                }
            }
        }
    }

    @ViewBuilder
    private var phoneRow: some View {
        HStack {
            Label(localizer.string(\CommonStrings.authFieldPhoneOptional), \.phone).foregroundStyle(\.secondary)
            Spacer()
            #if os(iOS)
            TextField(localizer.string(\CommonStrings.authFieldPhoneOptional), text: $phone)
                .multilineTextAlignment(.trailing).keyboardType(.phonePad).onChange(of: phone) { _ in hasEdits = true }
            #else
            TextField(localizer.string(\CommonStrings.authFieldPhoneOptional), text: $phone)
                .multilineTextAlignment(.trailing).onChange(of: phone) { _ in hasEdits = true }
            #endif
        }
    }

    private var displayName: String {
        if let fullName = user?.fullName, !fullName.isEmpty { return fullName }
        return user?.email ?? localizer.string(\CommonStrings.accountTitle)
    }

    private func saveChanges() {
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        onSaveProfile?(f.isEmpty ? nil : f, l.isEmpty ? nil : l, p.isEmpty ? nil : p)
        hasEdits = false
    }
}
