import SwiftUI

/// Primary CTA — accent fill, near-square (Paggo small radius).
struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.brand(.subheadline, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .background(
                Theme.accent.opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            )
    }
}

/// Secondary action — muted surface with hairline stroke.
struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.brand(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.vertical, 10)
            .background(
                Theme.surfaceHigh.opacity(configuration.isPressed ? 0.6 : 1),
                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}
