import SwiftUI
import AuthKit
import DesignTokensKit
import LocalizationKit

/// Profile information section for UserSettingsView displaying name, email, and phone.
public struct UserSettingsProfileSection: View {
    public let user: AuthUser?
    public let localizer: any AuthLocalizing
    public let onSaveProfile: ((_ email: String?, _ firstName: String?, _ lastName: String?, _ phone: String?) -> Void)?

    @State private var email: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var hasEdits: Bool = false

    public init(
        user: AuthUser?, localizer: (any AuthLocalizing)? = nil,
        onSaveProfile: ((_ email: String?, _ firstName: String?, _ lastName: String?, _ phone: String?) -> Void)? = nil
    ) {
        self.user = user; self.localizer = localizer ?? DefaultAuthLocalizer(); self.onSaveProfile = onSaveProfile
        _email = State(initialValue: user?.email ?? "")
        _firstName = State(initialValue: user?.firstName ?? "")
        _lastName = State(initialValue: user?.lastName ?? "")
        _phone = State(initialValue: user?.phone ?? "")
    }

    public init(
        user: AuthUser?, localizer: (any AuthLocalizing)? = nil,
        onSaveProfile: ((_ firstName: String?, _ lastName: String?, _ phone: String?) -> Void)?
    ) {
        self.init(user: user, localizer: localizer, onSaveProfile: onSaveProfile.map { cb in { cb($1, $2, $3) } })
    }

    public var body: some View {
        Section(localizer.string(\CommonStrings.authSectionProfile)) {
            HStack(spacing: \.twelve) {
                Image(\.personCropCircle).foregroundStyle(\.secondary)
                VStack(alignment: .leading, spacing: \.two) {
                    Text(displayName).font(\.headline).foregroundStyle(user != nil ? \.primary : \.secondary)
                    Text(email.isEmpty ? (user?.email ?? localizer.string(\CommonStrings.accountTitle)) : email)
                        .font(\.subheadline).foregroundStyle(\.secondary)
                }
            }
            .padding(.vertical, \.two)

            textRow(\CommonStrings.authFieldEmail, \.envelope, $email, isEmail: true)
            textRow(\CommonStrings.authFieldFirstName, \.person, $firstName)
            textRow(\CommonStrings.authFieldLastName, \.person, $lastName)
            textRow(\CommonStrings.authFieldPhoneOptional, \.phone, $phone, isPhone: true)

            if hasEdits, onSaveProfile != nil {
                Button(action: saveChanges) { Label(localizer.string(\CommonStrings.authButtonSaveProfile), \.checkmark) }
            }
        }
    }

    @ViewBuilder
    private func textRow(
        _ title: KeyPath<CommonStrings, String>, _ sym: KeyPath<SymbolTheme, AppSymbol>,
        _ text: Binding<String>, isEmail: Bool = false, isPhone: Bool = false
    ) -> some View {
        HStack {
            Label(localizer.string(title), sym).foregroundStyle(\.secondary)
            Spacer()
            #if os(iOS)
            if isEmail {
                TextField(localizer.string(title), text: text).multilineTextAlignment(.trailing)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: text.wrappedValue) { _ in hasEdits = true }
            } else if isPhone {
                TextField(localizer.string(title), text: text).multilineTextAlignment(.trailing)
                    .keyboardType(.phonePad).onChange(of: text.wrappedValue) { _ in hasEdits = true }
            } else {
                TextField(localizer.string(title), text: text).multilineTextAlignment(.trailing)
                    .onChange(of: text.wrappedValue) { _ in hasEdits = true }
            }
            #else
            TextField(localizer.string(title), text: text).multilineTextAlignment(.trailing)
                .onChange(of: text.wrappedValue) { _ in hasEdits = true }
            #endif
        }
    }

    private var displayName: String {
        guard let name = user?.fullName, !name.isEmpty else { return email.isEmpty ? (user?.email ?? "") : email }
        return name
    }

    private func saveChanges() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        onSaveProfile?(e != user?.email && !e.isEmpty ? e : nil, f.isEmpty ? nil : f, l.isEmpty ? nil : l, p.isEmpty ? nil : p)
        hasEdits = false
    }
}
