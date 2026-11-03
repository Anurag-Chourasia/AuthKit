import Foundation

/// Protocol for localizing authentication and account surfaces in AuthKitUI.
/// Compatible with `LocalizationProviding` from `LocalizationKit`.
public protocol AuthLocalizing: Sendable {
    func string(_ key: String) -> String
    var isRightToLeft: Bool { get }
}

public extension AuthLocalizing {
    var isRightToLeft: Bool { false }
}

/// Default built-in localizer using standard portfolio English strings.
public struct DefaultAuthLocalizer: AuthLocalizing {
    public let isRightToLeft: Bool
    private let customStrings: [String: String]

    private static let defaultStrings: [String: String] = [
        "auth.title.sign_in": "Sign in",
        "auth.title.create_account": "Create account",
        "auth.title.reset_password": "Reset password",
        "auth.title.choose_new_password": "Choose a new password",
        "auth.field.email": "Email",
        "auth.field.password": "Password",
        "auth.field.confirm_password": "Confirm password",
        "auth.button.forgot_password": "Forgot password?",
        "auth.button.create_an_account": "Create an account",
        "auth.button.back_to_sign_in": "Back to sign in",
        "auth.button.sign_out": "Sign out",
        "auth.button.delete_account": "Delete account",
        "auth.or_continue_with": "or continue with",
        "auth.status.please_wait": "Please wait",
        "auth.instruction.password_requirements": "Use at least 8 characters. Passwords must match.",
        "auth.instruction.reset_email_sent": "We’ll email you a link to choose a new password. Open it on this device.",
        "account.title": "Account",
        "account.signed_in": "Signed in",
        "account.delete_confirmation_title": "Delete Account?",
        "account.delete_confirmation_action": "Delete Account Permanently",
        "account.delete_confirmation_message": "This will permanently remove your cloud identity and records. You cannot undo this action.",
        "account.delete_footer_notice": "Permanently deletes your account credentials and associated cloud records across this portfolio.",
        "account.done": "Done",
        "common.cancel": "Cancel"
    ]

    public init(isRightToLeft: Bool = false, customStrings: [String: String] = [:]) {
        self.isRightToLeft = isRightToLeft
        self.customStrings = customStrings
    }

    public func string(_ key: String) -> String {
        customStrings[key] ?? Self.defaultStrings[key] ?? key
    }
}
