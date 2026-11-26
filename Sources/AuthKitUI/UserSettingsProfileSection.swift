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
    @State private var isSaving: Bool = false
    @State private var saveSuccess: Bool = false

    public init(
        user: AuthUser?, localizer: (any AuthLocalizing)? = nil,
        onSaveProfile: ((_ email: String?, _ firstName: String?, _ lastName: String?, _ phone: String?) -> Void)? = nil
    ) {
        self.user = user; self.localizer = localizer ?? DefaultAuthLocalizer(); self.onSaveProfile = onSaveProfile
        _email = State(initialValue: user?.email ?? ""); _firstName = State(initialValue: user?.firstName ?? "")
        _lastName = State(initialValue: user?.lastName ?? ""); _phone = State(initialValue: user?.phone ?? "")
    }

    public init(user: AuthUser?, localizer: (any AuthLocalizing)? = nil,
                onSaveProfile: ((_ first: String?, _ last: String?, _ phone: String?) -> Void)?) {
        self.init(user: user, localizer: localizer, onSaveProfile: onSaveProfile.map { cb in { cb($1, $2, $3) } })
    }

    private var isModified: Bool {
        let curEmail = email.trimmingCharacters(in: .whitespaces)
        let curFirst = firstName.trimmingCharacters(in: .whitespaces)
        let curLast = lastName.trimmingCharacters(in: .whitespaces)
        let curPhone = phone.trimmingCharacters(in: .whitespaces)
        return curEmail != (user?.email ?? "").trimmingCharacters(in: .whitespaces) ||
               curFirst != (user?.firstName ?? "").trimmingCharacters(in: .whitespaces) ||
               curLast != (user?.lastName ?? "").trimmingCharacters(in: .whitespaces) ||
               curPhone != (user?.phone ?? "").trimmingCharacters(in: .whitespaces)
    }

    private var canSave: Bool {
        (hasEdits || isModified) && onSaveProfile != nil
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

            if canSave {
                Button(action: saveChanges) {
                    HStack {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else if saveSuccess {
                            Image(\.checkmark).foregroundStyle(\.brandPrimary)
                        }
                        Label(localizer.string(\CommonStrings.authButtonSaveProfile), \.checkmark)
                    }
                }
                .disabled(isSaving)
            }
        }
        .onDisappear { if hasEdits || isModified { saveChanges() } }
        .onChange(of: user) { u in
            guard let u else { return }
            email = u.email ?? ""; firstName = u.firstName ?? ""; lastName = u.lastName ?? ""; phone = u.phone ?? ""
            hasEdits = false
        }
        .onChange(of: email) { _ in hasEdits = true }
        .onChange(of: firstName) { _ in hasEdits = true }
        .onChange(of: lastName) { _ in hasEdits = true }
        .onChange(of: phone) { _ in hasEdits = true }
    }

    @ViewBuilder
    private func textRow(
        _ title: KeyPath<CommonStrings, String>, _ sym: KeyPath<SymbolTheme, AppSymbol>,
        _ text: Binding<String>, isEmail: Bool = false, isPhone: Bool = false
    ) -> some View {
        HStack {
            Label(localizer.string(title), sym).foregroundStyle(\.secondary)
            Spacer()
            TextField(localizer.string(title), text: text).multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(isEmail ? .emailAddress : (isPhone ? .phonePad : .default))
                .textInputAutocapitalization(isEmail ? .never : .words)
                #endif
                .autocorrectionDisabled(isEmail || isPhone)
        }
    }

    private var displayName: String {
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last = lastName.trimmingCharacters(in: .whitespaces)
        let parts = [first, last].filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if let name = user?.fullName, !name.isEmpty { return name }
        return email.isEmpty ? (user?.email ?? "") : email
    }

    private func saveChanges() {
        guard !isSaving else { return }
        let (e, f) = (email.trimmingCharacters(in: .whitespaces), firstName.trimmingCharacters(in: .whitespaces))
        let (l, p) = (lastName.trimmingCharacters(in: .whitespaces), phone.trimmingCharacters(in: .whitespaces))
        isSaving = true
        onSaveProfile?(
            e != user?.email && !e.isEmpty ? e : nil,
            f, l, p
        )
        hasEdits = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            isSaving = false
            saveSuccess = true
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            saveSuccess = false
        }
    }
}
