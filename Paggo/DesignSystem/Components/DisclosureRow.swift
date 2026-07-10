import SwiftUI

/// A tappable row: optional leading icon + title + optional trailing summary + chevron.
/// The Mercury-style filter-list row that opens a drawer when tapped.
struct DisclosureRow: View {
    let title: String
    var icon: String? = nil           // optional leading SF Symbol
    var iconTint: Color = Theme.accent
    var value: String? = nil          // trailing summary, e.g. "2 selecionados"
    var valueColor: Color = Theme.textSecondary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if let icon {
                    TintedIcon(symbol: icon, tint: iconTint, size: 32, symbolSize: 13)
                }
                Text(title)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: Spacing.sm)
                if let value, !value.isEmpty {
                    Text(value)
                        .font(.brand(.caption, weight: .medium))
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
