import SwiftUI

/// Detalhe de uma conta — layout plano inspirado no benchmark (sem cards): header centralizado,
/// valor em destaque, grupos de linhas rótulo/valor separados apenas por hairlines.
struct AccountDetailView: View {
    let account: BankAccount
    @Environment(BankStore.self) private var bank

    private var transactions: [BankTransaction] { bank.recentTransactions(for: account.id) }
    private var isLoadingTransactions: Bool { bank.isLoadingTransactions(for: account.id) }
    private var transactionsError: String? { bank.transactionsError(for: account.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                groupDivider

                detailsGroup

                groupDivider

                balancesGroup

                groupDivider

                statusRow

                groupDivider
                statement
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .screenBackground()
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: account.id) { await bank.loadTransactions(for: account.id) }
    }

    // MARK: Header — logo + saldo em destaque

    private var header: some View {
        VStack(spacing: Spacing.md) {
            BankBadge(account: account, size: 64, ring: true)

            VStack(spacing: 4) {
                Text(account.balance.currencyFromCents())
                    .font(.heroNumber)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(account.accountNumberDisplay)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.lg)
    }

    // MARK: Grupos de linhas

    private var detailsGroup: some View {
        VStack(spacing: Spacing.lg) {
            row("Titular", account.organizationName ?? "—")
            row("Documento", account.taxId)
            row("Banco", "\(account.bank.shortName) · \(account.bankCode)")
            row("Agência", account.branchCode)
            row("Conta", account.accountNumberDisplay, copyable: account.accountNumberDisplay)
            row("Tipo", account.accountType.label)
            if let pix = account.pixKey, !pix.isEmpty {
                row("Chave Pix", pix, copyable: pix)
            }
        }
    }

    private var balancesGroup: some View {
        VStack(spacing: Spacing.lg) {
            row("Saldo total", account.balance.currencyFromCents(), emphasized: true)
            if let available = account.availableBalance {
                row("Disponível", available.currencyFromCents(), valueColor: Theme.positive)
            }
            if let predicted = account.predictedExpenses, predicted > 0 {
                row("Previsto a pagar", predicted.currencyFromCents(), valueColor: Theme.warning)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: Spacing.md) {
            Text("Status")
                .font(.brand(.body))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: Spacing.md)
            HStack(spacing: 6) {
                Circle().fill(Theme.positive).frame(width: 7, height: 7)
                Text(account.isExternal ? "Conectada" : "Ativa")
                    .font(.brand(.body, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: Extrato — linhas planas

    private var statement: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Movimentações recentes")
                .font(.brand(size: 18, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, Spacing.xs)

            if isLoadingTransactions && transactions.isEmpty {
                statementSkeleton
            } else if transactions.isEmpty {
                statementEmpty
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                        BankTransactionRow(transaction: tx).padding(.vertical, Spacing.md)
                        if index < transactions.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statementSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: Spacing.md) {
                    Skeleton(width: 34, height: 34, cornerRadius: Radius.pill)
                    VStack(alignment: .leading, spacing: 6) {
                        Skeleton(width: 140, height: 13)
                        Skeleton(width: 80, height: 11)
                    }
                    Spacer()
                    Skeleton(width: 72, height: 14)
                }
                .padding(.vertical, Spacing.md)
                if index < 3 { Divider().overlay(Theme.separator) }
            }
        }
    }

    private var statementEmpty: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: transactionsError == nil ? "tray" : "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(Theme.textTertiary)
            Text(transactionsError ?? "Nenhuma movimentação recente.")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if transactionsError != nil {
                Button("Tentar novamente") {
                    Task { await bank.loadTransactions(for: account.id) }
                }
                .font(.brand(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: Building blocks

    private var groupDivider: some View {
        Divider().overlay(Theme.separator).padding(.vertical, Spacing.lg)
    }

    private func row(_ label: String, _ value: String,
                     valueColor: Color = Theme.textPrimary,
                     emphasized: Bool = false,
                     copyable: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(label)
                .font(.brand(.body))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: Spacing.md)
            Text(value)
                .font(.brand(.body, weight: emphasized ? .semibold : .medium))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
            if let copyable {
                Button {
                    UIPasteboard.general.string = copyable
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
