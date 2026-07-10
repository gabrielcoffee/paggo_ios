import SwiftUI

/// "Transações" — extrato da carteira atual, agrupado por dia. Espelha modules/transactions do
/// apps/wallet-pwa (cabeçalhos Hoje/Ontem/dia, badges Validada e Pendências, navega para o detalhe).
struct WalletTransactionsView: View {
    @Environment(WalletStore.self) private var wallet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var path: [WalletPayment] = []
    // Debug: PAGGO_WALLET_PICKER=1 abre o seletor de escopo direto (verificação de UI).
    @State private var pickerOpen = ProcessInfo.processInfo.environment["PAGGO_WALLET_PICKER"] == "1"

    private var payments: [WalletPayment] { wallet.scopedPayments }

    /// Mostrar de qual carteira é cada linha (escopo "Todas").
    private var showsWalletIdentity: Bool { wallet.transactionsScope == .all }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Título custom (mesma serifa da nav bar) com o seletor de cartão à direita.
                HStack(alignment: .center, spacing: Spacing.md) {
                    Text("Extrato")
                        .font(.system(size: 32, design: .serif))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if !wallet.wallets.isEmpty {
                        WalletScopeButton(isOpen: $pickerOpen)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                ZStack(alignment: .topTrailing) {
                    list
                    // Dropdown flutua sobre a lista, descendo do topo; tocar fora fecha.
                    if pickerOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(WalletScopeMenu.animation(reduceMotion: reduceMotion)) {
                                    pickerOpen = false
                                }
                            }
                        WalletScopeMenu(isOpen: $pickerOpen)
                            .padding(.horizontal, Spacing.lg)
                            .transition(WalletScopeMenu.transition)
                    }
                }
            }
            .padding(.top, Spacing.sm)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .screenBackground(tint: scopeTint)
            .animation(.easeInOut(duration: 0.4), value: scopeTintKey)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: WalletPayment.self) { payment in
                WalletTransactionDetailView(payment: payment)
            }
        }
        // Debug: PAGGO_WALLET_DETAIL=1 abre direto o detalhe da 1ª transação (verificação de UI).
        .onChange(of: payments.count, initial: true) { _, _ in
            if ProcessInfo.processInfo.environment["PAGGO_WALLET_DETAIL"] == "1",
               path.isEmpty, let first = payments.first {
                path = [first]
            }
        }
    }

    // MARK: Lista

    @ViewBuilder private var list: some View {
        ScrollView {
            if payments.isEmpty {
                emptyState
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.lg, pinnedViews: [.sectionHeaders]) {
                    ForEach(grouped, id: \.key) { group in
                        Section {
                            VStack(spacing: Spacing.md) {
                                ForEach(group.items) { payment in
                                    NavigationLink(value: payment) { row(payment) }
                                        .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            dayHeader(group.label)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .refreshable { await wallet.load(force: true) }
    }

    // MARK: Aurora (cor do cartão do escopo; "Todas" volta ao padrão)

    private var scopeTint: Color? {
        switch wallet.transactionsScope {
        case .current: return WalletCardStyle.at(wallet.styleIndex(for: wallet.currentWallet)).accent
        case .wallet(let id):
            return WalletCardStyle.at(wallet.styleIndex(for: wallet.wallets.first { $0.id == id })).accent
        case .all: return nil
        }
    }

    /// Chave Equatable para animar a troca de tint (Color não serve como value de .animation).
    private var scopeTintKey: String {
        switch wallet.transactionsScope {
        case .current: return wallet.currentWallet?.id ?? "current"
        case .wallet(let id): return id
        case .all: return "all"
        }
    }

    // MARK: Grouping

    private func date(_ payment: WalletPayment) -> Date {
        DateText.parse(payment.createdAt) ?? .distantPast
    }

    private var grouped: [(key: Date, label: String, items: [WalletPayment])] {
        let cal = Calendar.current
        let sorted = payments.sorted { date($0) > date($1) }
        let groups = Dictionary(grouping: sorted) { cal.startOfDay(for: date($0)) }
        return groups.keys.sorted(by: >).map { day in (day, dayLabel(day), groups[day] ?? []) }
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Hoje" }
        if cal.isDateInYesterday(day) { return "Ontem" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        let daysAgo = cal.dateComponents([.day], from: day, to: Date()).day ?? 99
        f.dateFormat = daysAgo < 7 ? "EEEE" : "d 'de' MMMM"
        return f.string(from: day).capitalized
    }

    private func time(_ payment: WalletPayment) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f.string(from: date(payment))
    }

    // MARK: Rows

    private func dayHeader(_ label: String) -> some View {
        Text(label)
            .font(.brand(.caption, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.xs)
            // Sem barra: as linhas passam por trás do texto e somem num fade gradual.
            .background {
                LinearGradient(stops: [.init(color: Theme.base, location: 0),
                                       .init(color: Theme.base, location: 0.55),
                                       .init(color: Theme.base.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .padding(.bottom, -Spacing.lg)   // estende o fade abaixo do texto
            }
    }

    private func row(_ payment: WalletPayment) -> some View {
        let owner = wallet.wallet(for: payment)
        let style = WalletCardStyle.at(wallet.styleIndex(for: owner))
        return HStack(spacing: Spacing.md) {
            // Cartão dono + método da transação num ícone só.
            WalletMiniCard(style: style, symbol: payment.method.icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.receiverName.uppercased())
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(payment.status == .failed ? Theme.textTertiary : Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: Spacing.sm) {
                    Text(payment.receiverTaxId)
                        .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
                    Text(time(payment))
                        .font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
                    if payment.status == .confirmed && payment.released {
                        Label("Validada", systemImage: "checkmark.seal.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 11)).foregroundStyle(Theme.positive)
                    }
                }
                // Escopo "Todas": nome da carteira dona (a cor já vem do mini cartão).
                if showsWalletIdentity, let owner {
                    Text(owner.name)
                        .font(.brand(.caption2, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 4) {
                Text(payment.amount.currencyFromCents())
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(payment.status == .failed ? Theme.textTertiary : Theme.textPrimary)
                    .monospacedDigit()
                trailingFlag(payment)
            }
        }
        .padding(Spacing.md)
        .cardSurface()
    }

    @ViewBuilder
    private func trailingFlag(_ payment: WalletPayment) -> some View {
        if payment.status == .failed {
            Text("Falhou").font(.brand(.caption2, weight: .medium)).foregroundStyle(Theme.negative)
        } else if payment.hasPendencies {
            Text("Pendências")
                .font(.brand(.caption2, weight: .semibold))
                .foregroundStyle(Theme.negative)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Theme.negative.opacity(0.12), in: Capsule())
        } else if payment.hasAttachments {
            Image(systemName: "paperclip")
                .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 34)).foregroundStyle(Theme.textTertiary)
            Text("Você ainda não fez nenhum pagamento.")
                .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Text("Assim que pagar algo, aparecerá aqui.")
                .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxxl * 2)
    }
}
