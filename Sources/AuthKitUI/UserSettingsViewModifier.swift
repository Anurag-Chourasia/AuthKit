import SwiftUI
import AuthKit
import LocalizationKit
import DesignTokensKit

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

    @ViewBuilder
    func applyModalSheetStyle(background: Color = BrandPalette.current.background) -> some View {
        #if os(iOS)
        if #available(iOS 16.4, *) {
            self
                .presentationBackground(background)
                .presentationDragIndicator(.visible)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
