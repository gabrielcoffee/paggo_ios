import SwiftUI

/// Seletor de Carteira Digital — lista as carteiras do usuário (estilo do seletor de contas).
struct WalletPickerSheet: View {
    let wallets: [Wallet]
    let selectedID: String?
    var onSelect: (Wallet) -> Void

    var body: some View {
        SheetScaffold(title: "Escolha o cartão", closePlacement: .topBarLeading,
                      detents: [.medium, .large]) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(wallets.enumerated()), id: \.element.id) { index, item in
                        Button { onSelect(item) } label: { row(item) }
                            .buttonStyle(.plain)
                        if index < wallets.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private func row(_ item: Wallet) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: "wallet.bifold", tint: item.active ? Theme.accent : Theme.textTertiary,
                       size: 38, symbolSize: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text((item.active ? "" : "(desativado) ") + item.name)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("Limite: \(item.limit.currencyFromCents())")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            if item.id == selectedID {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}
