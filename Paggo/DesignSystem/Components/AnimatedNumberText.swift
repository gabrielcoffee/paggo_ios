import SwiftUI

/// Money value that animates between values using `numericText`. Seeds the displayed value to the
/// real target on first render (no count-up-from-zero) so it never flashes `R$ 0` before appearing.
struct AnimatedNumberText: View {
    /// Value in **reais** (already converted from cents by the caller).
    let value: Double
    var font: Font = .heroNumber
    var color: Color = Theme.textPrimary
    var compact: Bool = false

    @State private var displayed: Double

    init(value: Double, font: Font = .heroNumber, color: Color = Theme.textPrimary, compact: Bool = false) {
        self.value = value
        self.font = font
        self.color = color
        self.compact = compact
        _displayed = State(initialValue: value)
    }

    private var formatted: String {
        compact ? displayed.currencyCompact() : displayed.currencyExact()
    }

    var body: some View {
        Text(formatted)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: displayed))
            .onChange(of: value) { _, newValue in
                withAnimation(.snappy(duration: 0.5)) { displayed = newValue }
            }
    }
}

/// A signed delta chip, e.g. ▲ 4.2% / ▼ R$ 12 — green for positive, red for negative.
struct DeltaChip: View {
    let value: Double
    var isPercent: Bool = false
    var positiveIsGood: Bool = true

    private var isPositive: Bool { value >= 0 }
    private var tint: Color {
        let good = positiveIsGood ? isPositive : !isPositive
        return good ? Theme.positive : Theme.negative
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 9, weight: .bold))
            Text(isPercent ? String(format: "%.2f%%", abs(value)) : abs(value).currencyCompact())
                .font(.brand(.footnote, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(tint.opacity(0.14), in: Capsule())
    }
}
