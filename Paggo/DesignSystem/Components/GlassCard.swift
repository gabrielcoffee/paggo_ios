import SwiftUI

/// Content card. Defaults to a solid, elevated dark surface (Liquid Glass discipline:
/// glass is reserved for the navigation layer). Pass `glass: true` only for rare
/// floating elements over rich content.
struct GlassCard<Content: View>: View {
    var glass: Bool = false
    var padding: CGFloat = Spacing.lg
    var cornerRadius: CGFloat = Radius.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if glass {
                    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Theme.stroke, lineWidth: 1)
                        }
                }
            }
    }
}

/// Convenience modifier for arbitrary views to sit on a card surface.
extension View {
    func cardSurface(cornerRadius: CGFloat = Radius.lg) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}
