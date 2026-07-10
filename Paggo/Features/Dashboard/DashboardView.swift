import SwiftUI

/// Dashboard — visão geral das contas: saldo consolidado, histórico, entradas/saídas e contas.
struct DashboardView: View {
    @Environment(BankStore.self) private var bank
    @Environment(AuthStore.self) private var auth
    @State private var showTransfer = false

    var body: some View {
        @Bindable var bank = bank
        NavigationStack {
            ScrollView {
                if let error = bank.loadError, !bank.hasLoaded {
                    errorState(error)
                } else if !bank.hasLoaded {
                    // Gate no `hasLoaded` (não em `isLoading`): antes do 1º load o saldo real ainda
                    // não chegou — mostrar skeleton, nunca renderizar o hero com totalBalance 0.
                    loadingState
                } else {
                    VStack(spacing: Spacing.xl) {
                        if bank.isOffline { offlineBanner }
                        balanceHero
                        if bank.hasMovements { insights }
                        sectionSeparator
                        accountsSection
                        sectionSeparator
                        recentActivity
                        sectionSeparator
                        upcomingActivity
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable { await bank.load(force: true) }
            .screenBackground()
            .navigationTitle("Visão geral")
            .task { await bank.load() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileMenu() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        bank.balanceHidden.toggle()
                    } label: {
                        Image(systemName: bank.balanceHidden ? "eye.slash" : "eye")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showTransfer = true
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .disabled(bank.accounts.count < 2)
                }
            }
            .sheet(isPresented: $showTransfer) {
                TransferView(accounts: bank.accounts) {
                    Task { await bank.load(force: true) }
                }
            }
            .task {
                // Debug: PAGGO_OPEN_TRANSFER=1 abre o fluxo de transferência (verificação de UI).
                if ProcessInfo.processInfo.environment["PAGGO_OPEN_TRANSFER"] == "1" {
                    await bank.load()
                    showTransfer = true
                }
            }
        }
    }

    // MARK: Load states

    private var loadingState: some View { DashboardLoadingSkeleton() }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34)).foregroundStyle(Theme.textTertiary)
            Text(message)
                .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tentar novamente") { Task { await bank.load(force: true) } }
                .buttonStyle(PrimaryActionStyle())
        }
        .padding(Spacing.xl).frame(maxWidth: .infinity).padding(.top, Spacing.xxxl)
    }

    private var offlineBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.slash").font(.system(size: 12, weight: .semibold))
            Text("Modo offline — exibindo dados salvos")
                .font(.brand(.caption, weight: .medium))
        }
        .foregroundStyle(Theme.warning)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(Theme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }

    // MARK: Hero — saldo consolidado

    private var deltaPct: Double {
        guard let first = bank.history.first?.balance, first > 0,
              let last = bank.history.last?.balance else { return 0 }
        return Double(last - first) / Double(first) * 100
    }

    private var balanceHero: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text("Saldo total")
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                if bank.balanceHidden {
                    Text("••••••")
                        .font(.heroNumber)
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    AnimatedNumberText(value: bank.totalBalance.asReais, font: .heroNumber, compact: true)
                }

                HStack(spacing: Spacing.sm) {
                    DeltaChip(value: deltaPct, isPercent: true, positiveIsGood: true)
                    Text(bank.historyRange.deltaCaption)
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.top, Spacing.sm)

            rangePicker

            ZStack {
                BalanceChart(points: bank.history)
                if bank.isLoadingHistory {
                    ProgressView().tint(Theme.accent)
                }
            }

            HStack {
                heroMetric("Contas", "\(bank.accounts.count)")
                Divider().frame(height: 28).overlay(Theme.separator)
                heroMetric("Disponível", bank.totalBalance.currencyFromCents(), hidden: bank.balanceHidden)
            }
        }
        .padding(.vertical, Spacing.md)
    }

    private var rangePicker: some View {
        SegmentedControl(options: BalanceHistoryRange.allCases, selection: bank.historyRange,
                         label: { $0.shortLabel }, equalWidth: false) { range in
            Task { await bank.selectRange(range) }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func heroMetric(_ label: String, _ value: String, hidden: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
            Text(hidden ? "••••" : value)
                .font(.brand(.subheadline, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Insights — entradas / saídas

    private var insights: some View {
        HStack(spacing: 0) {
            flowCard(title: "Entradas", value: bank.movements.income.total, count: bank.movements.income.count,
                     symbol: "arrow.down.left", tint: Theme.positive)
            Divider().frame(height: 46).overlay(Theme.separator)
            flowCard(title: "Saídas", value: bank.movements.expense.total, count: bank.movements.expense.count,
                     symbol: "arrow.up.right", tint: Theme.negative)
        }
    }

    private func flowCard(title: String, value: Int, count: Int, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                TintedIcon(symbol: symbol, tint: tint, size: 26, symbolSize: 12, symbolWeight: .bold)
                Text(title).secondaryLabel()
            }
            Text(bank.balanceHidden ? "••••" : value.currencyCompactFromCents())
                .font(.brand(.title3, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text("\(count) movimentações")
                .font(.brand(.caption))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: Contas

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("Contas Bancárias", chevron: true)
            VStack(spacing: 0) {
                ForEach(Array(bank.accounts.enumerated()), id: \.element.id) { index, account in
                    NavigationLink {
                        AccountDetailView(account: account)
                    } label: {
                        AccountCardView(account: account, hidden: bank.balanceHidden)
                    }
                    .buttonStyle(.plain)
                    if index < bank.accounts.count - 1 {
                        Divider().overlay(Theme.separator)
                    }
                }
            }
        }
    }

    // MARK: Atividade recente

    private var recentActivity: some View {
        let recent = Array(bank.allRecentTransactions.prefix(6))
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("Últimas Transações", chevron: true)
            if recent.isEmpty {
                emptyRow("tray", "Nenhuma transação recente")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, tx in
                        BankTransactionRow(transaction: tx)
                            .padding(.vertical, Spacing.md)
                        if index < recent.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
    }

    // MARK: Próximas transações (agendadas — mock por enquanto)

    private var upcomingActivity: some View {
        // Já ordenado ascendente pelo backend — não reordenar.
        let upcoming = bank.upcomingPayments
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("Próximas Transações", chevron: true)
            if upcoming.isEmpty {
                emptyRow("calendar", "Nenhum pagamento agendado")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, payment in
                        UpcomingTransactionRow(payment: payment)
                            .padding(.vertical, Spacing.md)
                        if index < upcoming.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
    }

    /// Linha de estado vazio de uma seção (sem transações / sem agendamentos).
    private func emptyRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
            Text(text)
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.vertical, Spacing.lg)
    }

    private var sectionSeparator: some View {
        Divider().overlay(Theme.separator)
    }
}

/// Skeleton de carregamento do dashboard — linhas planas (sem cards), espelha o layout carregado.
struct DashboardLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.sm) {
                Skeleton(width: 90, height: 12)
                Skeleton(width: 180, height: 34, cornerRadius: Radius.md)
                Skeleton(width: 120, height: 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.lg)
            Skeleton(height: 150, cornerRadius: Radius.md)
            Divider().overlay(Theme.separator)
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: Spacing.md) {
                        Skeleton(width: 29, height: 29, cornerRadius: 14.5)
                        VStack(alignment: .leading, spacing: 6) {
                            Skeleton(width: 150, height: 13)
                            Skeleton(width: 100, height: 10)
                        }
                        Spacer()
                        Skeleton(width: 84, height: 13)
                    }
                    .padding(.vertical, Spacing.md)
                    if i < 4 { Divider().overlay(Theme.separator) }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
}

/// Linha de pagamento agendado — destaca a data futura com ícone de calendário.
private struct UpcomingTransactionRow: View {
    let payment: UpcomingPayment

    var body: some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: "calendar", symbolSize: 15, symbolWeight: .semibold, opacity: 0.12)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.receiverName.capitalized)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("Agendado · \(DateText.withMonth(payment.paymentDate))")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text("−" + payment.paymentAmount.currencyFromCents())
                .font(.brand(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
