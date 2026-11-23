import SwiftUI
import AuthKit
import LocalizationKit

extension View {
    @MainActor
    public func userSettingsSheet<Content: View>(
        isPresented: Binding<Bool>,
        session: SessionManager,
        localizer: (any AuthLocalizing)? = nil,
        aboutConfiguration: UserSettingsAboutConfiguration? = nil,
        @ViewBuilder additionalContent: @escaping () -> Content = { EmptyView() }
    ) -> some View {
        sheet(isPresented: isPresented) {
            UserSettingsSheet(
                session: session,
                localizer: localizer,
                aboutConfiguration: aboutConfiguration,
                onDismiss: { isPresented.wrappedValue = false },
                additionalContent: additionalContent
            )
        }
    }
}
