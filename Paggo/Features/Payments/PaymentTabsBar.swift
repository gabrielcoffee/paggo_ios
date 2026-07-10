import SwiftUI

/// Barra de tabs roláveis com contagem por status (espelha as tabs do Payout).
struct PaymentTabsBar: View {
    @Binding var selection: PackageTab
    let counts: [PackageTab: Int]

    @Namespace private var ns

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(PackageTab.allCases) { tab in
                        chip(tab)
                            .id(tab)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.xs)
            }
            .onChange(of: selection) { _, new in
                withAnimation(.snappy) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private func chip(_ tab: PackageTab) -> some View {
        let isSelected = tab == selection
        let count = counts[tab] ?? 0
        return Button {
            withAnimation(.snappy) { selection = tab }
        } label: {
            HStack(spacing: 6) {
                Text(tab.title)
                    .font(.brand(.subheadline, weight: isSelected ? .semibold : .medium))
                Text("\(count)")
                    .font(.brand(.caption2, weight: .semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (isSelected ? Color.white.opacity(0.22) : Theme.surfaceHigh),
                        in: Capsule()
                    )
            }
            .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background {
                if isSelected {
                    Capsule().fill(Theme.accent)
                        .matchedGeometryEffect(id: "tab", in: ns)
                } else {
                    Capsule().fill(Theme.surface)
                        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
