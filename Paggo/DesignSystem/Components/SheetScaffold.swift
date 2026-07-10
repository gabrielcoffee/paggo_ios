import SwiftUI

/// Empty `ToolbarContent` used as the default for `SheetScaffold`'s extra-toolbar slot.
struct EmptyToolbarContent: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) { }
    }
}

/// Standard modal scaffold: `NavigationStack` + `screenBackground()` + inline title + close button
/// + an optional extra-toolbar slot. Removes the ~8-10 lines of boilerplate each sheet repeats.
struct SheetScaffold<Content: View, Toolbar: ToolbarContent>: View {
    let title: String
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .inline
    var closePlacement: ToolbarItemPlacement = .topBarTrailing
    var detents: Set<PresentationDetent>? = nil
    var onClose: (() -> Void)? = nil          // nil → uses Environment dismiss
    @ViewBuilder var content: () -> Content
    @ToolbarContentBuilder var extraToolbar: () -> Toolbar

    @Environment(\.dismiss) private var dismiss

    /// Full init with an extra-toolbar slot.
    init(title: String,
         titleDisplayMode: NavigationBarItem.TitleDisplayMode = .inline,
         closePlacement: ToolbarItemPlacement = .topBarTrailing,
         detents: Set<PresentationDetent>? = nil,
         onClose: (() -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content,
         @ToolbarContentBuilder extraToolbar: @escaping () -> Toolbar) {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.closePlacement = closePlacement
        self.detents = detents
        self.onClose = onClose
        self.content = content
        self.extraToolbar = extraToolbar
    }

    var body: some View {
        NavigationStack {
            content()
                .screenBackground()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(titleDisplayMode)
                .toolbar {
                    ToolbarItem(placement: closePlacement) {
                        Button { (onClose ?? { dismiss() })() } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    extraToolbar()
                }
        }
        .applyDetents(detents)
    }
}

extension SheetScaffold where Toolbar == EmptyToolbarContent {
    /// Convenience init when no extra toolbar is needed.
    init(title: String,
         titleDisplayMode: NavigationBarItem.TitleDisplayMode = .inline,
         closePlacement: ToolbarItemPlacement = .topBarTrailing,
         detents: Set<PresentationDetent>? = nil,
         onClose: (() -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.closePlacement = closePlacement
        self.detents = detents
        self.onClose = onClose
        self.content = content
        self.extraToolbar = { EmptyToolbarContent() }
    }
}

private extension View {
    /// Applies presentation detents only when a set was provided.
    @ViewBuilder
    func applyDetents(_ detents: Set<PresentationDetent>?) -> some View {
        if let detents {
            self.presentationDetents(detents)
        } else {
            self
        }
    }
}
