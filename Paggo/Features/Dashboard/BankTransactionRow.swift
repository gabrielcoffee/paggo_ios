import SwiftUI

/// Linha de transação bancária (crédito/débito).
struct BankTransactionRow: View {
    let transaction: BankTransaction

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: transaction.isCredit ? "arrow.down" : "arrow.up")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(transaction.isCredit ? Theme.positive : Theme.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text((transaction.counterpartyName ?? transaction.description).capitalized)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(DateText.withMonth(transaction.date))
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text((transaction.isCredit ? "+" : "−") + transaction.amount.currencyFromCents())
                .font(.brand(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.isCredit ? Theme.positive : Theme.textPrimary)
        }
    }
}
