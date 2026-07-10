import SwiftUI

/// Bloco de ação do hub (Início do funcionário): ícone + título + subtítulo opcional.
/// Quadrado, 2 por linha no grid; o hub é organizado por AÇÕES, não por números.
struct ActionTile: View {
    let title: String
    var subtitle: String?
    let symbol: String
    var tint: Color = Theme.accent
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    TintedIcon(symbol: symbol, tint: tint)
                    Spacer()
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.brand(.caption2, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.negative, in: Capsule())
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.brand(.caption))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}
