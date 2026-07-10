import SwiftUI

/// Card de conta bancária no Dashboard.
struct AccountCardView: View {
    let account: BankAccount
    var hidden: Bool = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            BankBadge(account: account, size: 29, grayscale: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.name)
                    .font(.brand(.body, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(account.accountNumberDisplay)
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.md)
            VStack(alignment: .trailing, spacing: 1) {
                Text(hidden ? "••••••" : account.balance.currencyFromCents())
                    .font(.brand(.body, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let predicted = account.predictedExpenses, predicted > 0 {
                    Text("a pagar \(hidden ? "••••" : predicted.currencyCompactFromCents())")
                        .font(.brand(.caption2))
                        .monospacedDigit()
                        .foregroundStyle(Theme.warning)
                        .lineLimit(1)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}
