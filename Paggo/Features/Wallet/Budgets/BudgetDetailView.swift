import SwiftUI

/// Detalhe do orçamento (visão do membro): consumo vs limite efetivo, aumento temporário
/// visível, gastos do período, "o que a política exige" (transparência antes do decline)
/// e pedido de aumento — máx. 1 pendente, regra do servidor.
struct BudgetDetailView: View {
    let membershipId: String

    @Environment(BudgetStore.self) private var budgets
    @Environment(CardStore.self) private var cardStore
    @Environment(ReimbursementStore.self) private var reimbursements
    @State private var policy: ResolvedPolicy?
    @State private var showsRequestSheet = false

    private var membership: BudgetMembership? { budgets.membership(id: membershipId) }
    private var budget: Budget? { membership.flatMap { budgets.budget(id: $0.budgetId) } }

    var body: some View {
        ScrollView {
            if let membership, let budget {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    hero(membership: membership, budget: budget)
                    if let pending = budgets.pendingRequest(membershipId: membership.id) {
                        pendingRequestCard(pending)
                    }
                    spendSection(membership: membership)
                    policySection
                    aboutSection(budget: budget)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .screenBackground()
        .navigationTitle(budget?.name ?? "Orçamento")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            if let membership, membership.status == .active, budget?.status == .active,
               budgets.pendingRequest(membershipId: membership.id) == nil {
                Button("Solicitar aumento de limite") { showsRequestSheet = true }
                    .buttonStyle(PrimaryActionStyle())
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
            }
        }
        .sheet(isPresented: $showsRequestSheet) {
            if let membership, let budget {
                LimitRequestSheet(membership: membership, budget: budget)
            }
        }
        .task {
            await budgets.load()
            await cardStore.load()
            await reimbursements.load()
            policy = try? await ServiceContainer.shared.policyRepository
                .resolvedPolicy(budgetId: budget?.id)
        }
    }

    // MARK: Hero

    private func hero(membership: BudgetMembership, budget: Budget) -> some View {
        let effective = membership.effectiveLimit(budgetTotal: budget.totalLimit)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("\(membership.remaining(budgetTotal: budget.totalLimit).currencyFromCents())")
                .font(.brand(size: 34, weight: .bold)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text("restantes do seu limite neste período")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
            ConsumptionBar(consumed: membership.consumed, limit: effective, height: 10, showsLabels: true)

            if let temp = membership.temporaryLimit, membership.temporaryLimitActive() {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Aumento temporário ativo até \(DateText.full(temp.validUntil)) — depois volta a \((membership.memberLimit ?? budget.totalLimit).currencyFromCents())")
                }
                .font(.brand(.caption))
                .foregroundStyle(Theme.info)
            }

            if membership.status == .suspended {
                Label("Sua participação está suspensa — novos gastos não podem ser marcados aqui.",
                      systemImage: "pause.circle")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.warning)
            }
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    private func pendingRequestCard(_ request: LimitRequest) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: "hourglass", tint: Theme.info)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pedido de aumento aguardando decisão")
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(request.currentLimit.currencyFromCents()) → \(request.requestedLimit.currencyFromCents()) · \(request.kindLabel.lowercased())")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    // MARK: Gastos do período (cartão + reembolsos deste orçamento)

    private func spendSection(membership: BudgetMembership) -> some View {
        let cardSpend = cardStore.transactions.filter { $0.membershipId == membership.id && $0.countsAsSpend }
        let reimb = reimbursements.items.filter { $0.budget?.id == membership.budgetId
            && ($0.status == .approved || $0.status == .paid) }

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Gastos do período")
            if cardSpend.isEmpty && reimb.isEmpty {
                Text("Nenhum gasto marcado neste orçamento ainda.")
                    .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg).cardSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(cardSpend) { tx in
                        spendRow(symbol: "creditcard", title: tx.merchant.name,
                                 detail: "Cartão · \(DateText.short(tx.authorizedAt))",
                                 amount: tx.effectiveAmount)
                        if tx.id != cardSpend.last?.id || !reimb.isEmpty { Divider().padding(.leading, 52) }
                    }
                    ForEach(reimb) { item in
                        spendRow(symbol: "arrow.uturn.backward.circle", title: item.description,
                                 detail: "Reembolso · \(DateText.short(item.expenseDate))",
                                 amount: item.amount)
                        if item.id != reimb.last?.id { Divider().padding(.leading, 52) }
                    }
                }
                .padding(.vertical, Spacing.xs)
                .cardSurface()
            }
        }
    }

    private func spendRow(symbol: String, title: String, detail: String, amount: Int) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: symbol, tint: Theme.neutralIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(amount.currencyFromCents())
                .font(.brand(.subheadline, weight: .semibold)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: "O que a política exige" — o funcionário lê a regra antes de esbarrar nela

    @ViewBuilder private var policySection: some View {
        if let policy {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("O que a política exige")
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let max = policy.maxPerTransaction {
                        policyRow(symbol: "arrow.up.to.line",
                                  text: "Teto por transação: \(max.currencyFromCents())")
                    }
                    if let receipt = policy.receiptRequiredAbove {
                        policyRow(symbol: "doc.text",
                                  text: "Recibo obrigatório em gastos a partir de \(receipt.currencyFromCents())")
                    }
                    if !policy.blockedCategories.isEmpty {
                        policyRow(symbol: "nosign",
                                  text: "Categorias bloqueadas: \(policy.blockedCategories.map(\.label).joined(separator: ", "))")
                    }
                    if let auto = policy.autoApproveBelow {
                        policyRow(symbol: "checkmark.seal",
                                  text: "Reembolsos abaixo de \(auto.currencyFromCents()) com recibo são aprovados na hora")
                    }
                }
                .padding(Spacing.lg)
                .cardSurface()
            }
        }
    }

    private func policyRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            Text(text)
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Sobre

    private func aboutSection(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Sobre o orçamento")
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let description = budget.description {
                    Text(description)
                        .font(.brand(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                }
                HStack {
                    Text("Período").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(budget.periodLabel).foregroundStyle(Theme.textPrimary)
                }
                .font(.brand(.subheadline))
                HStack {
                    Text("Teto total do time").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(budget.totalLimit.currencyFromCents()).monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                .font(.brand(.subheadline))
            }
            .padding(Spacing.lg)
            .cardSurface()
        }
    }
}
