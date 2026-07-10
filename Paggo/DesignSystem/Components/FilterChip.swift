import SwiftUI

/// A removable selected-filter pill (accent capsule + trailing X). Used in the "Selecionados"
/// section of the filter sheet.
struct FilterChip: View {
    let title: String          // e.g. "Pagador: ACME LTDA" or "Atraso: Sim"
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(title)
                .font(.brand(.caption, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, 7)
        .background(Theme.accent, in: Capsule())
    }
}
