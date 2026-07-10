import SwiftUI

/// Aba Avisos: pendências acionáveis + notificações — o funcionário resolve e fica em dia
/// num lugar só. Pendências são derivadas dos domínios na hora (nunca cacheadas); cada
/// linha leva direto pra tela onde se resolve.
struct NoticesView: View {
    @Environment(NoticeStore.self) private var notices
    @Environment(CardStore.self) private var cardStore
    @Environment(WalletStore.self) private var wallet
    @Environment(BudgetStore.self) private var budgets
    @Environment(ReimbursementStore.self) private var reimbursements

    var body: some View {
        NavigationStack {
            List {
                if !pendencies.isEmpty {
                    Section("Pendências") {
                        ForEach(pendencies) { item in
                            NavigationLink {
                                pendencyDestination(item)
                            } label: {
                                PendencyRow(title: item.title, detail: item.detail,
                                            symbol: item.symbol)
                            }
                        }
                    }
                }
                Section("Avisos") {
                    if notices.notifications.isEmpty && notices.hasLoaded {
                        Text("Nenhum aviso por aqui.")
                            .font(.brand(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(notices.notifications) { notification in
                        if hasDestination(notification) {
                            NavigationLink {
                                notificationDestination(notification)
                                    .onAppear {
                                        Task { await notices.markRead(id: notification.id) }
                                    }
                            } label: {
                                NotificationRow(notification: notification)
                            }
                        } else {
                            NotificationRow(notification: notification)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task { await notices.markRead(id: notification.id) }
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Avisos")
            .toolbar {
                if notices.unreadCount > 0 {
                    Button("Marcar todas") { Task { await notices.markAllRead() } }
                        .font(.brand(.subheadline, weight: .semibold))
                }
            }
            .task {
                await notices.load()
                await cardStore.load()
                await budgets.load()
                await reimbursements.load()
            }
            .refreshable {
                await notices.load(force: true)
                await cardStore.load(force: true)
            }
        }
    }

    // MARK: Pendências (derivadas)

    private enum PendencyTarget: Hashable {
        case cardTransaction(String)
        case payment(WalletPayment)
    }

    private struct PendencyItem: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let target: PendencyTarget
    }

    private var pendencies: [PendencyItem] {
        var items: [PendencyItem] = cardStore.missingReceipts.map {
            PendencyItem(id: "ctx-receipt-\($0.id)",
                         title: "Anexar recibo — \($0.merchant.name)",
                         detail: "\($0.effectiveAmount.currencyFromCents()) · \(DateText.short($0.authorizedAt))",
                         symbol: "doc.text.viewfinder",
                         target: .cardTransaction($0.id))
        }
        let allPayments = wallet.paymentsByWallet.values.flatMap { $0 }
        items += allPayments.filter(\.hasPendencies).map {
            PendencyItem(id: "pay-\($0.id)",
                         title: $0.hasAttachments ? "Completar alocação — \($0.receiverName)"
                                                  : "Anexar comprovante — \($0.receiverName)",
                         detail: "\($0.amount.currencyFromCents()) · \(DateText.short($0.createdAt))",
                         symbol: "chart.pie",
                         target: .payment($0))
        }
        return items
    }

    @ViewBuilder private func pendencyDestination(_ item: PendencyItem) -> some View {
        switch item.target {
        case .cardTransaction(let id): CardTransactionDetailView(transactionId: id)
        case .payment(let payment): WalletTransactionDetailView(payment: payment)
        }
    }

    // MARK: Deep-link das notificações (payload → tela do assunto)

    private func hasDestination(_ notification: AppNotification) -> Bool {
        guard let payload = notification.payload else { return false }
        if payload.transactionId != nil { return true }
        if payload.reimbursementId != nil { return true }
        if membershipId(for: payload) != nil { return true }
        return false
    }

    private func membershipId(for payload: AppNotification.Payload) -> String? {
        if let id = payload.membershipId { return id }
        if let budgetId = payload.budgetId {
            return budgets.memberships.first { $0.budgetId == budgetId }?.id
        }
        return nil
    }

    @ViewBuilder private func notificationDestination(_ notification: AppNotification) -> some View {
        if let payload = notification.payload {
            if let txId = payload.transactionId {
                CardTransactionDetailView(transactionId: txId)
            } else if let reimbursementId = payload.reimbursementId {
                ReimbursementDetailView(reimbursementId: reimbursementId)
            } else if let membershipId = membershipId(for: payload) {
                BudgetDetailView(membershipId: membershipId)
            }
        }
    }
}

private struct PendencyRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: symbol, tint: Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            TintedIcon(symbol: notification.type.symbol,
                       tint: notification.isUnread ? Theme.accent : Theme.neutralIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.brand(.subheadline, weight: notification.isUnread ? .semibold : .regular))
                    .foregroundStyle(Theme.textPrimary)
                Text(notification.body)
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
                Text(DateText.relative(notification.createdAt))
                    .font(.brand(.caption2))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if notification.isUnread {
                Circle().fill(Theme.accent).frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
    }
}
