import SwiftUI

/// Card compacto de orçamento (hub e lista): nome, restante e barra 75/90.
struct BudgetOverviewCard: View {
    let budget: Budget
    let membership: BudgetMembership

    private var effectiveLimit: Int { membership.effectiveLimit(budgetTotal: budget.totalLimit) }
    private var remaining: Int { membership.remaining(budgetTotal: budget.totalLimit) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(budget.name)
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if membership.status == .suspended {
                    Text("Suspenso")
                        .font(.brand(.caption2, weight: .bold))
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.14), in: Capsule())
                } else if budget.status == .expired {
                    Text("Expirado")
                        .font(.brand(.caption2, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.neutralFill.opacity(0.3), in: Capsule())
                } else {
                    Text(budget.periodLabel)
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Text("\(remaining.currencyFromCents()) restantes")
                .font(.brand(.title3, weight: .semibold)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            ConsumptionBar(consumed: membership.consumed, limit: effectiveLimit)
            HStack {
                Text("\(membership.consumed.currencyFromCents()) usados")
                Spacer()
                Text("limite \(effectiveLimit.currencyFromCents())")
            }
            .font(.brand(.caption))
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(Spacing.lg)
        .cardSurface()
    }
}

/// Lista completa "Meus orçamentos" (push a partir do hub).
struct BudgetsListView: View {
    @Environment(BudgetStore.self) private var budgets

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ForEach(budgets.overviews, id: \.membership.id) { pair in
                    NavigationLink {
                        BudgetDetailView(membershipId: pair.membership.id)
                    } label: {
                        BudgetOverviewCard(budget: pair.budget, membership: pair.membership)
                    }
                    .buttonStyle(.plain)
                }
                if budgets.overviews.isEmpty && budgets.hasLoaded {
                    emptyState
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .screenBackground()
        .navigationTitle("Meus orçamentos")
        .task { await budgets.load() }
        .refreshable { await budgets.load(force: true) }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chart.pie")
                .font(.system(size: 30)).foregroundStyle(Theme.textTertiary)
            Text("Você ainda não participa de nenhum orçamento")
                .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
            Text("Peça ao administrador para te adicionar a um orçamento do time.")
                .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .cardSurface()
    }
}
