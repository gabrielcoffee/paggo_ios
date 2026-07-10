import SwiftUI

/// Reembolsos do funcionário: lista por estado, previsão de pagamento visível desde a
/// aprovação e cancelamento enquanto em análise.
struct ReimbursementsListView: View {
    @Environment(ReimbursementStore.self) private var store
    @State private var showsForm = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ForEach(store.items) { item in
                    NavigationLink {
                        ReimbursementDetailView(reimbursementId: item.id)
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                }
                if store.items.isEmpty && store.hasLoaded {
                    emptyState
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .screenBackground()
        .navigationTitle("Reembolsos")
        .safeAreaInset(edge: .bottom) {
            Button("Novo reembolso") { showsForm = true }
                .buttonStyle(PrimaryActionStyle())
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)
        }
        .fullScreenCover(isPresented: $showsForm) {
            ReimbursementFormView()
        }
        .task { await store.load() }
        .refreshable { await store.load(force: true) }
    }

    private func row(_ item: Reimbursement) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: item.merchantCategory.symbol, tint: statusTint(item))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    statusChip(item)
                    if item.status == .approved, let estimated = item.estimatedPaymentDate {
                        Text("Pix até \(DateText.short(estimated))")
                            .font(.brand(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if item.wasAutoApproved {
                        Text("· pela política")
                            .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            Spacer()
            Text(item.amount.currencyFromCents())
                .font(.brand(.subheadline, weight: .semibold)).monospacedDigit()
                .foregroundStyle(item.status == .rejected || item.status == .canceled
                                 ? Theme.textTertiary : Theme.textPrimary)
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    private func statusChip(_ item: Reimbursement) -> some View {
        Text(item.statusLabel)
            .font(.brand(.caption2, weight: .semibold))
            .foregroundStyle(statusTint(item))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(statusTint(item).opacity(0.13), in: Capsule())
    }

    private func statusTint(_ item: Reimbursement) -> Color {
        switch item.status {
        case .submitted: return Theme.info
        case .approved: return Theme.warning
        case .paid: return Theme.positive
        case .rejected: return Theme.negative
        case .canceled: return Theme.textTertiary
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 30)).foregroundStyle(Theme.textTertiary)
            Text("Nenhum reembolso por aqui")
                .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
            Text("Gastou do próprio bolso a trabalho? Peça o reembolso com a foto do recibo.")
                .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .cardSurface()
    }
}

/// Detalhe do reembolso: linha do tempo, motivo de recusa e cancelamento.
struct ReimbursementDetailView: View {
    let reimbursementId: String

    @Environment(ReimbursementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var item: Reimbursement? { store.items.first { $0.id == reimbursementId } }

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    hero(item)
                    timeline(item)
                    infoCard(item)
                    if item.canCancel {
                        Button(role: .destructive) {
                            Task {
                                await store.cancel(id: item.id)
                                dismiss()
                            }
                        } label: {
                            Text("Cancelar reembolso")
                                .font(.brand(.subheadline, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionStyle())
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .screenBackground()
        .navigationTitle("Reembolso")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hero(_ item: Reimbursement) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(item.amount.currencyFromCents())
                .font(.brand(size: 34, weight: .bold)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(item.description)
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
            if let flags = item.policyFlags, !flags.isEmpty {
                Label("Sinalizado pra revisão: \(flags.map(flagLabel).joined(separator: ", "))",
                      systemImage: "exclamationmark.triangle")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.warning)
            }
            if let note = item.decisionNote {
                Text("“\(note)”")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.negative)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func flagLabel(_ flag: String) -> String {
        switch flag {
        case "over_max_amount": return "acima do teto"
        case "blocked_category": return "categoria bloqueada"
        default: return flag
        }
    }

    private func timeline(_ item: Reimbursement) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            timelineRow("Enviado", date: item.createdAt, done: true)
            switch item.status {
            case .submitted:
                timelineRow("Aguardando aprovação", date: nil, done: false)
            case .rejected:
                timelineRow("Recusado", date: item.decidedAt, done: true, tint: Theme.negative)
            case .canceled:
                timelineRow("Cancelado por você", date: item.updatedAt, done: true,
                            tint: Theme.textTertiary)
            case .approved:
                timelineRow(approvedLabel(item), date: item.decidedAt, done: true)
                timelineRow("Pix até \(item.estimatedPaymentDate.map(DateText.full) ?? "—") — o financeiro libera o pagamento",
                            date: nil, done: false)
            case .paid:
                timelineRow(approvedLabel(item), date: item.decidedAt, done: true)
                timelineRow("Pago na sua chave Pix", date: item.paidAt, done: true,
                            tint: Theme.positive)
            }
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    private func approvedLabel(_ item: Reimbursement) -> String {
        item.wasAutoApproved ? "Aprovado na hora pela política"
                             : "Aprovado por \(item.decidedBy?.name ?? "—")"
    }

    private func timelineRow(_ title: String, date: String?, done: Bool,
                             tint: Color = Theme.positive) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(done ? tint : Theme.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.brand(.subheadline, weight: done ? .medium : .regular))
                    .foregroundStyle(done ? Theme.textPrimary : Theme.textSecondary)
                if let date {
                    Text(DateText.full(date))
                        .font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private func infoCard(_ item: Reimbursement) -> some View {
        VStack(spacing: Spacing.md) {
            infoRow("Categoria", item.merchantCategory.label)
            infoRow("Data da despesa", DateText.full(item.expenseDate))
            infoRow("Orçamento", item.budget?.name ?? "Sem orçamento")
            infoRow("Recibo", item.receipt != nil ? "Anexado" : "—")
            infoRow("Chave Pix de recebimento", "\(item.payoutKey.type.rawValue.uppercased()) · \(item.payoutKey.value)")
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
