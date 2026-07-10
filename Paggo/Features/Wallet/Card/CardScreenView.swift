import SwiftUI
import UIKit

/// Cartão corporativo do funcionário: arte com reveal protegido, congelar/descongelar,
/// vínculos (orçamento + carteira lastro) e feed de compras com motivo de recusa legível.
struct CardScreenView: View {
    @Environment(CardStore.self) private var cardStore
    @Environment(BudgetStore.self) private var budgets

    @State private var revealed: RevealedCardDetails?
    @State private var revealTask: Task<Void, Never>?
    @State private var correctingTransaction: CardTransaction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if let card = cardStore.card {
                    cardArt(card)
                    if let reason = card.lockDescription {
                        Label(reason, systemImage: "lock.fill")
                            .font(.brand(.subheadline, weight: .medium))
                            .foregroundStyle(Theme.negative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.lg)
                            .cardSurface()
                    }
                    controls(card)
                    links(card)
                    feed
                } else if cardStore.hasLoaded {
                    emptyState
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .screenBackground()
        .navigationTitle("Cartão")
        .task { await cardStore.load() }
        .refreshable { await cardStore.load(force: true) }
        .onDisappear { hideRevealed() }
        .sheet(item: $correctingTransaction) { tx in
            CategoryCorrectionSheet(transaction: tx)
        }
    }

    // MARK: Arte

    private func cardArt(_ card: CorporateCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "creditcard.fill").font(.system(size: 20))
                Text(card.budget.name)
                    .font(.brand(.subheadline, weight: .semibold))
                Spacer()
                Text(card.brand.uppercased())
                    .font(.brand(.caption, weight: .bold))
                    .kerning(1.5)
            }
            .foregroundStyle(.white.opacity(0.92))

            Spacer()

            Group {
                if let revealed {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(revealed.groupedPan)
                            .font(.brand(size: 22, weight: .semibold)).monospacedDigit()
                            .onLongPressGesture { copy(revealed.pan, label: "Número copiado") }
                        HStack(spacing: Spacing.xl) {
                            Text("Val \(card.expiryLabel)")
                            Text("CVV \(revealed.cvv)")
                                .onLongPressGesture { copy(revealed.cvv, label: "CVV copiado") }
                        }
                        .font(.brand(.subheadline, weight: .medium)).monospacedDigit()
                        Text("Segure para copiar · some sozinho em instantes")
                            .font(.brand(.caption2))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .privacySensitive()
                } else {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("••••  ••••  ••••  \(card.last4)")
                            .font(.brand(size: 22, weight: .semibold)).monospacedDigit()
                        Text(card.holder.name.uppercased())
                            .font(.brand(.caption, weight: .medium))
                            .kerning(1.2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .foregroundStyle(.white)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1.72, contentMode: .fit)
        .background(
            LinearGradient(colors: card.status == .frozen
                           ? [Color(hex: "5A6572"), Color(hex: "39424C")]
                           : [Theme.accentDeep, Theme.accent.opacity(0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(alignment: .center) {
            if card.status == .frozen {
                Image(systemName: "snowflake")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: card.status)
        .animation(.easeInOut(duration: 0.25), value: revealed != nil)
    }

    // MARK: Controles

    private func controls(_ card: CorporateCard) -> some View {
        HStack(spacing: Spacing.md) {
            if card.status == .active || card.status == .frozen {
                controlButton(card.status == .frozen ? "Descongelar" : "Congelar",
                              symbol: "snowflake",
                              tint: card.status == .frozen ? Theme.info : Theme.textPrimary) {
                    Task { await cardStore.setFrozen(card.status == .active) }
                }
            }
            if card.status != .canceled {
                controlButton(revealed == nil ? "Revelar dados" : "Ocultar",
                              symbol: revealed == nil ? "eye" : "eye.slash",
                              tint: Theme.textPrimary) {
                    if revealed == nil { Task { await reveal() } } else { hideRevealed() }
                }
            }
        }
    }

    private func controlButton(_ title: String, symbol: String, tint: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                Text(title).font(.brand(.caption, weight: .semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .cardSurface()
        }
        .buttonStyle(.plain)
        .disabled(cardStore.isMutating)
    }

    /// Reveal exige biometria na hora; o dado exibido some sozinho e nunca é persistido.
    private func reveal() async {
        let auth = BiometricAuthenticator()
        let result = await auth.evaluateDeviceOwner(reason: "Revelar os dados do cartão")
        guard result == .success else {
            if result == .failed { ToastCenter.shared.show("Autenticação não concluída", style: .error) }
            return
        }
        do {
            revealed = try await cardStore.reveal()
            revealTask?.cancel()
            revealTask = Task {
                try? await Task.sleep(for: .seconds(45))
                if !Task.isCancelled { hideRevealed() }
            }
        } catch {
            ToastCenter.shared.show((error as? SpendError)?.userMessage ?? "Não foi possível revelar.",
                                    style: .error)
        }
    }

    private func hideRevealed() {
        revealTask?.cancel()
        revealed = nil
    }

    /// Clipboard local (não sincroniza com outros aparelhos) e com validade de 1 minuto.
    private func copy(_ value: String, label: String) {
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: value]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)]
        )
        ToastCenter.shared.show(label)
    }

    // MARK: Vínculos

    private func links(_ card: CorporateCard) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                if let membership = budgets.memberships.first(where: { $0.id == card.membershipId }) {
                    BudgetDetailView(membershipId: membership.id)
                }
            } label: {
                linkRow(symbol: "chart.pie", title: "Orçamento",
                        value: card.budget.name, chevron: true)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)
            linkRow(symbol: "wallet.bifold", title: "Carteira lastro",
                    value: card.wallet.name, chevron: false)
            Divider().padding(.leading, 52)
            linkRow(symbol: "calendar", title: "Validade",
                    value: card.expiryLabel, chevron: false)
        }
        .padding(.vertical, Spacing.xs)
        .cardSurface()
    }

    private func linkRow(symbol: String, title: String, value: String, chevron: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: symbol, tint: Theme.neutralIcon)
            Text(title)
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Feed

    private var feed: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Compras")
            if cardStore.transactions.isEmpty {
                Text("Nenhuma compra ainda.")
                    .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg).cardSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(cardStore.transactions) { tx in
                        Button { correctingTransaction = tx } label: {
                            transactionRow(tx)
                        }
                        .buttonStyle(.plain)
                        if tx.id != cardStore.transactions.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
                .cardSurface()
            }
        }
    }

    private func transactionRow(_ tx: CardTransaction) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: tx.merchant.category.symbol,
                       tint: tx.status == .declined ? Theme.negative : Theme.neutralIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.merchant.name)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text("\(DateText.short(tx.authorizedAt)) · \(tx.statusLabel)")
                        .font(.brand(.caption))
                        .foregroundStyle(tx.status == .declined ? Theme.negative : Theme.textSecondary)
                    if tx.countsAsSpend {
                        ComplianceIcons(receiptAttached: tx.receiptStatus == .attached,
                                        allocationDone: nil)
                    }
                }
                if let settled = tx.settledAmount, settled != tx.amount {
                    Text("Autorizado \(tx.amount.currencyFromCents()) → liquidado \(settled.currencyFromCents())")
                        .font(.brand(.caption2))
                        .foregroundStyle(Theme.warning)
                }
            }
            Spacer()
            Text(tx.effectiveAmount.currencyFromCents())
                .font(.brand(.subheadline, weight: .semibold)).monospacedDigit()
                .foregroundStyle(tx.status == .declined ? Theme.textTertiary : Theme.textPrimary)
                .strikethrough(tx.status == .declined || tx.status == .reversed,
                               color: Theme.textTertiary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "creditcard")
                .font(.system(size: 30)).foregroundStyle(Theme.textTertiary)
            Text("Você ainda não tem cartão")
                .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
            Text("O administrador emite o cartão virtual a partir de um orçamento.")
                .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .cardSurface()
    }
}

/// Correção manual da categoria vinda da rede (doc 02 regra 6) — alimenta o policy engine.
private struct CategoryCorrectionSheet: View {
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
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            .navigationTitle("Categoria da compra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
