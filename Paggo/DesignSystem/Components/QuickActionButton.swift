import SwiftUI

/// Circular Liquid Glass action button with an animated SF Symbol and a caption below.
struct QuickActionButton: View {
    let title: String
    let systemImage: String
    var prominent: Bool = false
    let action: () -> Void

    @State private var bounce = 0

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                bounce += 1
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                action()
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(prominent ? Color.white : Theme.textPrimary)
                    .frame(width: 42, height: 42)
                    .symbolEffect(.bounce, value: bounce)
            }
            .buttonStyle(.glass)
            .tint(prominent ? Theme.accent : nil)

            Text(title)
                .font(.brand(.caption2, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
