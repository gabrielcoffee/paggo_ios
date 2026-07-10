import SwiftUI

/// Detalhe de uma compra de cartão no extrato: valores (autorizado → liquidado), estado com
/// motivo, categoria (corrigível), recibo e vínculo com o orçamento.
struct CardTransactionDetailView: View {
    let transactionId: String

    @Environment(CardStore.self) private var cardStore
    @Environment(BudgetStore.self) private var budgets
    @State private var showsCategorySheet = false
    @State private var showsReceiptCapture = false

    private var transaction: CardTransaction? {
        cardStore.transactions.first { $0.id == transactionId }
    }

    var body: some View {
        ScrollView {
            if let tx = transaction {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    hero(tx)
                    detailsCard(tx)
                    if tx.countsAsSpend { receiptCard(tx) }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .screenBackground()
        .navigationTitle("Compra no cartão")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsCategorySheet) {
            if let tx = transaction {
                CardCategorySheet(transaction: tx)
            }
        }
        .sheet(isPresented: $showsReceiptCapture) {
            ReceiptCaptureSheet()
        }
    }

    private func hero(_ tx: CardTransaction) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(tx.merchant.name)
                .font(.brand(.title3, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(tx.effectiveAmount.currencyFromCents())
                .font(.brand(size: 34, weight: .bold)).monospacedDigit()
                .foregroundStyle(tx.status == .declined ? Theme.textTertiary : Theme.textPrimary)
                .strikethrough(tx.status == .declined || tx.status == .reversed,
                               color: Theme.textTertiary)
            HStack(spacing: Spacing.xs) {
                Image(systemName: statusSymbol(tx))
                    .font(.system(size: 12, weight: .semibold))
                Text(tx.statusLabel)
            }
            .font(.brand(.subheadline, weight: .medium))
            .foregroundStyle(statusColor(tx))

            if let settled = tx.settledAmount, settled != tx.amount {
                Text("Autorizado por \(tx.amount.currencyFromCents()); o valor final liquidado foi \(settled.currencyFromCents()). A diferença ajustou carteira e orçamento.")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.warning)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func detailsCard(_ tx: CardTransaction) -> some View {
        VStack(spacing: 0) {
            Button { showsCategorySheet = true } label: {
                infoRow(symbol: tx.merchant.category.symbol, title: "Categoria",
                        value: tx.merchant.category.label, chevron: true)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)
            infoRow(symbol: "chart.pie", title: "Orçamento", value: tx.budget.name, chevron: false)
            Divider().padding(.leading, 52)
            infoRow(symbol: "calendar", title: "Autorizada em",
                    value: DateText.full(tx.authorizedAt), chevron: false)
            if let settledAt = tx.settledAt {
                Divider().padding(.leading, 52)
                infoRow(symbol: "checkmark.circle", title: "Liquidada em",
                        value: DateText.full(settledAt), chevron: false)
            }
            if let city = tx.merchant.city {
                Divider().padding(.leading, 52)
                infoRow(symbol: "mappin.and.ellipse", title: "Local",
                        value: city, chevron: false)
            }
        }
        .padding(.vertical, Spacing.xs)
        .cardSurface()
    }

    private func receiptCard(_ tx: CardTransaction) -> some View {
        Button {
            if tx.receiptStatus == .missing { showsReceiptCapture = true }
        } label: {
            HStack(spacing: Spacing.md) {
                TintedIcon(symbol: "doc.text",
                           tint: tx.receiptStatus == .attached ? Theme.positive : Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.receiptStatus == .attached ? "Recibo anexado" : "Recibo pendente")
                        .font(.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(tx.receiptStatus == .attached
                         ? "Casado automaticamente pela leitura do recibo."
                         : "Fotografe o recibo desta compra — ele casa sozinho pelo valor e data.")
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if tx.receiptStatus == .missing {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(Spacing.lg)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private func infoRow(symbol: String, title: String, value: String, chevron: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: symbol, tint: Theme.neutralIcon)
            Text(title).font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func statusSymbol(_ tx: CardTransaction) -> String {
        switch tx.status {
        case .authorized: return "clock"
        case .settled: return "checkmark.circle.fill"
        case .reversed: return "arrow.uturn.left"
        case .declined: return "xmark.octagon.fill"
        }
    }

    private func statusColor(_ tx: CardTransaction) -> Color {
        switch tx.status {
        case .authorized: return Theme.warning
        case .settled: return Theme.positive
        case .reversed: return Theme.textTertiary
        case .declined: return Theme.negative
        }
    }
}

/// Correção de categoria a partir do extrato (mesma regra da tela do cartão).
struct CardCategorySheet: View {
    let transaction: CardTransaction
    @Environment(CardStore.self) private var cardStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(MerchantCategory.allCases) { category in
                Button {
                    Task {
                        await cardStore.correctCategory(transactionId: transaction.id,
                                                        category: category)
                        dismiss()
                    }
                } label: {
                    HStack {
                        Label(category.label, systemImage: category.symbol)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if category == transaction.merchant.category {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            .navigationTitle("Categoria da compra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
