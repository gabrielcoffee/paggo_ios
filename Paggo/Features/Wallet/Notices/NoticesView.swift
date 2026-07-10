import SwiftUI

/// Aba Avisos: pendências acionáveis + notificações — o funcionário resolve e fica em dia
/// num lugar só. Pendências são derivadas dos domínios na hora (nunca cacheadas).
struct NoticesView: View {
    @Environment(NoticeStore.self) private var notices
    @Environment(CardStore.self) private var cardStore
    @Environment(WalletStore.self) private var wallet

    var body: some View {
        NavigationStack {
            List {
                if !pendencies.isEmpty {
                    Section("Pendências") {
                        ForEach(pendencies) { item in
                            PendencyRow(item: item)
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
                        NotificationRow(notification: notification)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { await notices.markRead(id: notification.id) }
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
            }
            .refreshable {
                await notices.load(force: true)
                await cardStore.load(force: true)
            }
        }
    }

    /// Pendências derivadas: transações de cartão sem recibo + pendências do extrato da carteira.
    private var pendencies: [PendencyItem] {
        var items: [PendencyItem] = cardStore.missingReceipts.map {
            PendencyItem(id: "ctx-receipt-\($0.id)",
                         title: "Anexar recibo — \($0.merchant.name)",
                         detail: "\($0.effectiveAmount.currencyFromCents()) · \(DateText.short($0.authorizedAt))",
                         symbol: "doc.text.viewfinder")
        }
        let allPayments = wallet.paymentsByWallet.values.flatMap { $0 }
        items += allPayments.filter(\.hasPendencies).map {
            PendencyItem(id: "pay-\($0.id)",
                         title: $0.hasAttachments ? "Completar alocação — \($0.receiverName)"
                                                  : "Anexar comprovante — \($0.receiverName)",
                         detail: "\($0.amount.currencyFromCents()) · \(DateText.short($0.createdAt))",
                         symbol: "chart.pie")
        }
        return items
    }
}

private struct PendencyItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

private struct PendencyRow: View {
    let item: PendencyItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: item.symbol, tint: Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(item.detail)
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
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
