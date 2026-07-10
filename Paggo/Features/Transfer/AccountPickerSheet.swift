import SwiftUI

/// Avatar quadrado com as iniciais do banco/conta (placeholder de ícone).
struct AccountAvatar: View {
    let name: String
    var size: CGFloat = 42

    private var initials: String {
        let chars = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(chars).uppercased()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(Theme.surfaceHigh)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "building.columns.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .opacity(initials.isEmpty ? 1 : 0)
            )
            .overlay(
                Text(initials)
                    .font(.brand(.caption, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            )
    }
}

/// Lista de contas para escolher origem/destino (busca incluída), estilo Revolut "Choose a bank".
struct AccountPickerSheet: View {
    let title: String
    let accounts: [BankAccount]
    let selectedID: String?
    var onSelect: (BankAccount) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [BankAccount] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return accounts }
        return accounts.filter {
            ($0.name + " " + $0.bank.shortName + " " + $0.accountLabel).lowercased().contains(q)
        }
    }

    var body: some View {
        SheetScaffold(title: title, closePlacement: .topBarLeading, detents: [.large]) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, account in
                        Button { onSelect(account); dismiss() } label: { row(account) }
                            .buttonStyle(.plain)
                        if index < filtered.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                    if filtered.isEmpty {
                        Text("Nenhuma conta encontrada")
                            .font(.brand(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.xxxl)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Buscar conta")
        }
    }

    private func row(_ account: BankAccount) -> some View {
        HStack(spacing: Spacing.md) {
            BankBadge(account: account, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(account.accountLabel)
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: Spacing.md)
            Text(account.balance.currencyFromCents())
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            if account.id == selectedID {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}
