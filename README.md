# AuthKit

Private shared authentication for MyTV, ShowBook and Motivation Daily. iOS 16+;
Swift 6.2+. `AuthKit` contains the backend/session layer; `AuthKitUI` is optional
SwiftUI presentation built on the apps' DesignTokensKit and UIComponentsKit.

## Supported flows

- Email/password login and signup (including email-confirmation-required feedback).
- Forgot-password email, recovery callbacks and password updates.
- Google, GitHub and Apple through Supabase PKCE browser OAuth.
- SDK auth-event observation, restoration, refresh and local-only logout.
- MyTV, ShowBook and Motivation Daily branded login/signup/recovery screens.

Apple is browser OAuth, not a native Sign in with Apple button. Provider acceptance
and Apple branding review remain required before App Store submission.

## Host integration

```swift
import AuthKit
import AuthKitUI
import Supabase

// Use a distinct stable key and callback scheme for EACH app.
let callback = URL(string: "showbook-auth://auth/callback")!
let manager = SupabaseManager(
    url: URL(string: "https://YOUR_PROJECT.supabase.co")!,
    publishableKey: "YOUR_PUBLISHABLE_KEY",
    authOptions: .init(storageKey: "showbook.auth.session", redirectToURL: callback)
)
let session = SessionManager(authService: AuthService(
    backend: SupabaseAuthBackend(manager: manager)
))
// Retain session as a StateObject at the app root.
// Run this even after the login view disappears:
// .task { await session.observeAuthChanges() }
// Render recovery FIRST, even when state is authenticated:
// if session.isPasswordRecovery { AuthView(...) }
// else switch session.state { ... }
AuthView(session: session, brand: .showBook, redirectTo: callback,
         providers: [.google, .github, .apple])
```

Use `.myTV` / `.motivationDaily` for the other styles. Providers default to empty:
only expose providers you have configured and tested. Keep SessionManager alive
across auth/content navigation. Auth observation emits the initial session, so a
separate restore call is optional. Cancellation removes the observation task.

Register each callback URL scheme in its host's Info.plist (or use configured
universal links). Allowlist the exact callbacks in Supabase Auth URL configuration.
In the app's onOpenURL, compare scheme, host and path with its configured callback
before forwarding email confirmation/recovery URLs to `await session.handleCallback(url)`.
Browser OAuth consumes its own callback; do not exchange that callback twice.
Never log callback URLs, passwords, access tokens or refresh tokens.

For MyTV and Motivation Daily use separate schemes such as `mytv-auth` and
`motivationdaily-auth`. Do not share Keychain access groups. Shared Supabase project
accounts then have independent stored sessions; logout uses `.local` scope. Changing
an existing storage key requires a migration or sign-in again.

## Supabase/provider configuration required

Enable email/password and configure SMTP, confirmation and password-recovery templates.
Recovery links must return to the same app installation that requested the PKCE email.
Enable Google and GitHub with their provider OAuth credentials and Supabase callback URL.
For Apple configure a Services ID, website redirect, team/key identifiers and signing
secret in Supabase. Provider credentials belong in Supabase, never in this package.
The publishable key is client configuration; never embed service-role/admin keys.
The UI requires at least eight password characters; enforce your actual password
policy in Supabase. Email/password/provider flows still need live acceptance testing.

## Session ordering

SessionManager accepts one active operation. Controls disable during network/browser
requests; overlapping programmatic calls return without starting another operation.
SDK events are authoritative and prevent late operation results overwriting newer
session events. Observe changes from the app root to receive sign-out, refresh,
user updates and password recovery. Errors preserve existing state except failed
explicit restoration/login, which leave the session unauthenticated.

`AuthService.signUp` retains its existing Bool contract: true means confirmation is
required (no session returned). SessionManager exposes a human-readable notice.

## Validation / CI

Run `swift test` under Xcode 27.1. UI compile validation:

```sh
xcodebuild -scheme AuthKitUI -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AuthKitDerived -scmProvider system CODE_SIGNING_ALLOWED=NO build
```

Live lifecycle tests use memory storage and require SUPABASE_URL,
SUPABASE_PUBLISHABLE_KEY, SUPABASE_TEST_EMAIL and SUPABASE_TEST_PASSWORD, with an
existing confirmed test account. Without credentials, only these live tests skip.
Offline tests cover SDK storage restoration/isolation, service operations, session
state transitions, recovery events and concurrent-operation rejection.

CI runs offline tests and builds iOS UI. Separate read-only deploy keys provide
private design-package access. No coverage-percentage or live-provider acceptance
claim is made. AuthKit supplies reusable screens; host app navigation/persistence
migration and live Supabase/provider configuration remain host integration work.

## Offline UI demo

Open `Examples/AuthKitDemo/AuthKitDemo.xcodeproj` and run AuthKitDemo. Switch between
all three brands, open signup and forgot-password screens, and exercise form validation.
This demo uses an isolated fake backend; it does not create cloud accounts or contact
OAuth providers. Provider taps intentionally return an unsupported-URL error.
The layout-only rendering tests produce image attachments, but ImageRenderer replaces
UIKit text fields with placeholders; inspect actual controls in this demo.

Provider references: [Supabase Swift OAuth](https://supabase.com/docs/reference/swift/auth-signinwithoauth),
[auth events](https://supabase.com/docs/reference/swift/auth-onauthstatechange),
[password recovery](https://supabase.com/docs/guides/auth/passwords).

## App brand palettes

Brand cores: MyTV electric blue #2563EB; ShowBook deep navy #00064F; Motivation Daily
warm amber #B45309. Host catalogs own AuthAction, AuthOnAction, AuthBackground and
AuthForeground, each with light/dark variants. AuthView automatically passes these
assets through AuthPalette; missing host assets fall back to bundled brand defaults.
Provider marks retain their own colors for recognition.

DesignTokensKit owns spacing, typography, geometry and semantic role definitions.
UIComponentsKit owns reusable controls and their interaction/accessibility behaviour.
AuthKitUI owns authentication composition. Product-specific brand hex values belong
in each host's catalog rather than being built into shared token/component APIs.

Define a palette in each host app as branding evolves, then pass it to the auth view:

```swift
let palette = AuthPalette(action: Color("AccentColor"), onAction: .white,
                          background: Color("AuthBackground"), foreground: .primary)
AuthView(session: session, brand: .showBook, redirectTo: callback,
         providers: [.google, .github, .apple], palette: palette)
```

Use color assets with light/dark variants. Choose onAction for contrast against your
chosen action color; it is independent of foreground text and provider-button colors.

## Host app gate (0.2.0)

AppAuthGate wraps each host's existing content and observes auth events at the root.
It presents recovery before authenticated content and provides Account / local sign-out.
Configuration is read from SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, AUTH_CALLBACK_URL
and AUTH_PROVIDERS in the host Info.plist. AUTH_PROVIDERS is a comma-separated list
of enabled providers; leave empty until those providers are configured in Supabase.
Missing configuration fails closed. Callback handling matches scheme, host and path.

The three hosts register these callbacks, which must also be allowlisted in Supabase:
- mytv-auth://auth/callback
- showbook-auth://auth/callback
- motivationdaily-auth://auth/callback

Each app stores its session under its bundle identifier plus `.supabase.session`.
ShowBook binds cloud identity before loading bookmarks; legacy local account passwords
are not migrated or used to authenticate Supabase. MyTV and Motivation Daily favourites
remain local device data; this integration does not add cloud sync or per-account data migration.
