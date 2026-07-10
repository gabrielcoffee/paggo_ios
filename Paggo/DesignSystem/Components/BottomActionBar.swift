import SwiftUI

/// Pinned `.ultraThinMaterial` footer bar. The caller supplies the buttons (single full-width,
/// or a half/half `HStack`). Used as a `safeAreaInset(edge: .bottom)`.
struct BottomActionBar<Content: View>: View {
    var horizontalPadding: CGFloat = Spacing.lg
    var verticalPadding: CGFloat = Spacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.top, verticalPadding)
            .padding(.bottom, verticalPadding)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
    }
}
