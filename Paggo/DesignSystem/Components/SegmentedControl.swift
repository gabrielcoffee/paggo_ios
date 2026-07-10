import SwiftUI

/// Capsule segmented control. The selected segment fills with `Theme.accent`; the rest sit on the
/// input surface with a hairline border. Two flavors:
///  - `equalWidth: true` (default) — segments share the row equally (status / type / priority pickers).
///  - `equalWidth: false` — segments hug their content (compact pill rows like the balance range).
///
/// Use the `Binding` init for plain selection, or the action init when selecting triggers a side
/// effect (e.g. an async reload).
struct SegmentedControl<T: Hashable & Identifiable>: View {
    let options: [T]
    let selection: T
    let label: (T) -> String
    var equalWidth: Bool = true
    let onSelect: (T) -> Void

    /// Binding-driven selection (the common case).
    init(selection: Binding<T>, options: [T], label: @escaping (T) -> String, equalWidth: Bool = true) {
        self.options = options
        self.selection = selection.wrappedValue
        self.label = label
        self.equalWidth = equalWidth
        self.onSelect = { selection.wrappedValue = $0 }
    }

    /// Action-driven selection — for side effects beyond setting a value.
    init(options: [T], selection: T, label: @escaping (T) -> String,
         equalWidth: Bool = true, onSelect: @escaping (T) -> Void) {
        self.options = options
        self.selection = selection
        self.label = label
        self.equalWidth = equalWidth
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(options) { option in
                segment(option)
            }
        }
    }

    @ViewBuilder
    private func segment(_ option: T) -> some View {
        let isSelected = option == selection
        Button { withAnimation(.snappy) { onSelect(option) } } label: {
            Text(label(option))
                .font(.brand(.caption, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
                .frame(maxWidth: equalWidth ? .infinity : nil)
                .padding(.horizontal, equalWidth ? 0 : Spacing.md)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule().fill(Theme.accent)
                    } else {
                        Capsule().fill(Theme.surface).overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
